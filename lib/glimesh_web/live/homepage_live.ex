defmodule GlimeshWeb.HomepageLive do
  use GlimeshWeb, :surface_live_view

  alias Glimesh.Accounts
  alias Glimesh.QueryCache

  alias GlimeshWeb.Channels.Components.ChannelPreview
  alias GlimeshWeb.Channels.Components.CarouselPlayer
  alias GlimeshWeb.Events.Components.EventMedia

  alias Surface.Components.LiveRedirect

  @impl true
  def render(assigns) do
    ~F"""
    <div class="carousel-homepage-bg pt-4">
      <div class="row mt-6">
        <div class="col-lg-2 user-sidebar">
          <div class="card carousel-first-menu" style="right: -50px">
            <div class="list-group list-group-flush">
            <h4> Filter </h4><p></p>
              <p>{gettext("Events")}</p>
              <p>{gettext("Live Streams")}</p>
              <p>{gettext("Categories")}</p>
            </div>
          </div><br>
          <div class="row mt-6">
        <div class="col-lg-2 user-sidebar">
          <div class="card carousel-first-menu" style="right: -50px">
            <div class="list-group list-group-flush">
              <p><i class="fas fa-user fa-fw" /> {gettext("Gaming")}</p>
              <p><i class="fas fa-user fa-fw" /> {gettext("Art")}</p>
              <p><i class="fas fa-user fa-fw" /> {gettext("Music")}</p>
              <p><i class="fas fa-user fa-fw" /> {gettext("Tech")}</p>
              <p><i class="fas fa-user fa-fw" /> {gettext("IRL")}</p>
              <p><i class="fas fa-user fa-fw" /> {gettext("Education")}</p>
            </div>
          </div>
        </div>
        </div>
        </div>
        <div>
          <CarouselPlayer channels={@channels} id="top-carousel" muted />
        </div>
      </div>

      {#if length(@channels) > 0}
        <div class="container container-stream-list">
          <div class="row">
            {#for channel <- @channels}
              <ChannelPreview channel={channel} class="col-sm-12 col-md-6 col-xl-4 mt-2 mt-md-4" />
            {/for}
          </div>
        </div>
      {/if}

      <div class="container">
        <div class="mt-4 px-4 px-lg-0">
          <h2>{gettext("Categories Made Simpler")}</h2>
          <p class="lead">{gettext("Explore our categories and find your new home!")}</p>
        </div>
        <div class="row mt-2 mb-4">
          {#for {name, link, icon} <- list_categories()}
            <div class="col">
              <LiveRedirect to={link} class="btn btn-outline-primary btn-lg btn-block py-4">
                <i class={"fas fa-2x fa-fw", icon} />
                <br>
                <small class="text-color-link">{name}</small>
              </LiveRedirect>
            </div>
          {/for}
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    maybe_user = Accounts.get_user_by_session_token(session["user_token"])
    # If the viewer is logged in set their locale, otherwise it defaults to English
    if session["locale"], do: Gettext.put_locale(session["locale"])

    raw_channels = get_cached_channels()

    random_channel = get_random_channel(raw_channels)

    upcoming_event = Glimesh.EventsTeam.get_one_upcoming_event()

    [live_featured_event, live_featured_event_channel] = get_random_event()

    channels =
      if is_nil(live_featured_event_channel),
        do: raw_channels,
        else: [live_featured_event_channel | raw_channels]

    user_count = Glimesh.Accounts.count_users()

    if connected?(socket) do
      live_channel_id =
        cond do
          not is_nil(live_featured_event_channel) -> live_featured_event_channel.id
          not is_nil(random_channel) -> random_channel.id
          true -> nil
        end

      if live_channel_id do
        CarouselPlayer.play("top-carousel", Map.get(session, "country"))

        Glimesh.Presence.track_presence(
          self(),
          Glimesh.Streams.get_subscribe_topic(:viewers, live_channel_id),
          session["unique_user"],
          %{}
        )
      end
    end

    {:ok,
     socket
     |> put_page_title()
     |> assign(:upcoming_event, upcoming_event)
     |> assign(:live_featured_event, live_featured_event)
     |> assign(:live_featured_event_channel, live_featured_event_channel)
     |> assign(:channels, channels)
     |> assign(:random_channel, random_channel)
     |> assign(:random_channel_thumbnail, get_stream_thumbnail(random_channel))
     |> assign(:user_count, user_count)
     |> assign(:current_user, maybe_user)}
  end

  def list_categories do
    [
      {
        gettext("Gaming"),
        ~p"/streams/gaming",
        "fa-gamepad"
      },
      {
        gettext("Art"),
        ~p"/streams/art",
        "fa-palette"
      },
      {
        gettext("Music"),
        ~p"/streams/music",
        "fa-headphones"
      },
      {
        gettext("Tech"),
        ~p"/streams/tech",
        "fa-microchip"
      },
      {
        gettext("IRL"),
        ~p"/streams/irl",
        "fa-camera-retro"
      },
      {
        gettext("Education"),
        ~p"/streams/education",
        "fa-graduation-cap"
      }
    ]
  end

  def get_random_event do
    QueryCache.get_and_store!("GlimeshWeb.HomepageLive.get_random_event()", fn ->
      live_featured_events = Glimesh.EventsTeam.get_potentially_live_featured_events()

      if length(live_featured_events) > 0 do
        random_event = Enum.random(live_featured_events)
        random_channel = Glimesh.ChannelLookups.get_channel_for_username(random_event.channel)

        if Glimesh.Streams.is_live?(random_channel) do
          {:ok, [random_event, random_channel]}
        else
          {:ok, [nil, nil]}
        end
      else
        {:ok, [nil, nil]}
      end
    end)
  end

  def handle_event("webrtc_error", value, socket) do
    {:noreply, socket}
  end

  defp get_stream_thumbnail(%Glimesh.Streams.Channel{} = channel) do
    case channel.stream do
      %Glimesh.Streams.Stream{} = stream ->
        Glimesh.StreamThumbnail.url({stream.thumbnail, stream}, :original)

      _ ->
        Glimesh.ChannelPoster.url({channel.poster, channel}, :original)
    end
  end

  defp get_stream_thumbnail(nil), do: nil

  defp get_cached_channels do
    QueryCache.get_and_store!("GlimeshWeb.HomepageLive.get_cached_channels()", fn ->
      {:ok, Glimesh.Homepage.get_homepage()}
    end)
  end

  defp get_random_channel(channels) when length(channels) > 0 do
    QueryCache.get_and_store!("GlimeshWeb.HomepageLive.get_random_channel()", fn ->
      {:ok, Enum.random(channels)}
    end)
  end

  defp get_random_channel(_), do: nil

  @impl Phoenix.LiveView
  def handle_info({:debug, _, _}, socket) do
    # Ignore any debug messages from the video player
    {:noreply, socket}
  end
end
