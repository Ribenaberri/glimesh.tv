defmodule GlimeshWeb.Channels.Components.CarouselPlayer do
  use GlimeshWeb, :surface_live_component

  alias Glimesh.Streams.Channel

  alias Surface.Components.LiveRedirect

  prop(channels, :any)
  prop(country, :string)
  prop(muted, :boolean, default: false)

  data(status, :string, default: "")
  data(current_index, :integer)

  def render(assigns) do
    ~F"""
    {#for channel <- [Enum.at(@channels, @current_index)]}
    <div class="card shadow rounded" style="right: -350px">
            <div
          class="carousel-control-prev" width="10px"
          role="button"
          :on-click="prev_channel"
          phx-value-current={@current_index}
          phx-value-max={Enum.count(@channels)}
        >
        <i class="fas fa-chevron-left" />
        </div>
        <div
          class="carousel-control-next"
          role="button"
          :on-click="next_channel"
          phx-value-current={@current_index}
          phx-value-max={Enum.count(@channels)}
        >
        <i class="fas fa-chevron-right" />
        </div>
      <div id="carousel-video-container" class="embed-responsive embed-responsive-16by9">
        <video
          id="carousel-video"
          class="embed-responsive-item"
          :hook="CarouselPlayer"
          controls
          playsinline
          poster={get_stream_thumbnail(channel)}
          muted={@muted}
          data-channel-id={channel.id}
          data-status={@status}
          data-rtrouter={Application.get_env(:glimesh, :rtrouter_url)}
        >
        </video>
    </div>
        <div class="card carousel-homepage-card">
        <div class="d-flex align-items-start p-2">
          <img
            src={Glimesh.Avatar.url({channel.user.avatar, channel.user}, :original)}
            alt={channel.user.displayname}
            width="48"
            height="48"
            class={[
              "img-avatar mr-2",
              if(Glimesh.Accounts.can_receive_payments?(channel.user),
                do: "img-verified-streamer"
              )
            ]}
          />
          <div class="pl-1 pr-1">
            <h6 class="mb-0 mt-1 text-wrap pride_channel_title">
              {channel.title}
            </h6>
            <p class="mb-0 card-stream-username">
              {channel.user.displayname}
              <span class="badge badge-info">
                {Glimesh.Streams.get_channel_language(channel)}
              </span>
              {#if channel.mature_content}
                <span class="badge badge-warning ml-1">{gettext("Mature")}</span>
              {/if}
            </p>
          </div>
          <LiveRedirect
            to={~p"/#{channel.user.username}"}
            class="ml-auto text-md-nowrap mt-1 btn carousel-homepage-btn"
          >{gettext("Watch Live")}
          </LiveRedirect>
        </div>
      </div>
        <div id="video-loading-container" class="">
          <div class="lds-ring">
            <div />
            <div />
            <div />
            <div />
          </div>
        </div>
        <div
          class="carousel-control-prev"
          role="button"
          :on-click="prev_channel"
          phx-value-current={@current_index}
          phx-value-max={Enum.count(@channels)}
        >
        <i class="fas fa-chevron-left fa-2xl" />
        </div>
        <div
          class="carousel-control-next"
          role="button"
          :on-click="next_channel"
          phx-value-current={@current_index}
          phx-value-max={Enum.count(@channels)}
        >
        <i class="fas fa-chevron-right" />
        </div>
      </div>
    {/for}
    <div class="card carousel-next-gen" style="left: 750px">
    <div class="d-left align-left p-2">
    <h1>
    <span style="color:#67EFD6">
    Next-Gen </span> Live Streaming!
    </h1>
    <br>
    The first live streaming platform built around truly real-time interactivity.
    Our streams are warp speed, our chat is blazing, and our community is thriving.
    </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:conn, socket)
     |> assign(:current_index, 0)}
  end

  @impl true
def handle_event("next_channel", value, socket) do
  current_index = String.to_integer(Map.fetch!(value, "current"))
  max_index = String.to_integer(Map.fetch!(value, "max"))

  next_index = if current_index == max_index - 1, do: 0, else: current_index + 1

  {:noreply,
    socket
    |> assign(:current_index, next_index)}
end

@impl true
def handle_event("prev_channel", value, socket) do
  current_index = String.to_integer(Map.fetch!(value, "current"))
  max_index = String.to_integer(Map.fetch!(value, "max"))

  next_index = if current_index == 0, do: max_index - 1, else: current_index - 1

  {:noreply,
    socket
    |> assign(:current_index, next_index)}
end

  def play(player_id, _country) do
    send_update(__MODULE__, id: player_id, status: "ready")
  end

  defp get_stream_thumbnail(%Channel{} = channel) do
    case channel.stream do
      %Glimesh.Streams.Stream{} = stream ->
        Glimesh.StreamThumbnail.url({stream.thumbnail, stream}, :original)

      _ ->
        Glimesh.ChannelPoster.url({channel.poster, channel}, :original)
    end
  end
end
