defmodule GlimeshWeb.UserLive.Components.ReportButton do
  use GlimeshWeb, :live_view

  alias Glimesh.Accounts

  @impl true
  def render(assigns) do
    ~L"""
      <%= if @show_button do %>
      <div class="text-center">
        <a href="#" phx-click="show_modal" class="text-danger">
          <%= gettext("Report User") %> <i class="fas fa-flag"></i>
        </a>
      </div>
      <%= if live_flash(@flash, :report_info) do %>
      <p class="alert alert-info" role="alert"
          phx-click="lv:clear-flash"
          phx-value-key="report_info"><%= live_flash(@flash, :report_info) %></p>
      <% end %>

      <%= if @show_report do %>
       <div id="reportModal" class="live-modal"
            phx-capture-click="hide_modal"
            phx-window-keydown="hide_modal"
            phx-key="escape"
            phx-target="#paymentModal2"
            phx-page-loading>
            <div class="modal-dialog" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Report User</h5>
                        <button type="button" class="close" phx-click="hide_modal" aria-label="Close">
                          <span aria-hidden="true">&times;</span>
                        </button>
                    </div>

                    <div class="modal-body">

                      <%= form_for :user, "#", [phx_submit: :save] %>
                      <div class="form-group">
                        <label for="reportLocation"><%= gettext("Where did this happen?") %></label>
                        <select name="location" class="form-control" id="reportLocation" aria-describedby="locationHelp">
                          <option><%= gettext("Select One") %></option>
                          <option><%= gettext("Stream Video Content") %></option>
                          <option><%= gettext("Stream Chat") %></option>
                          <option><%= gettext("Profile Text or Avatar") %></option>
                          <option><%= gettext("Username") %></option>
                          <option><%= gettext("Not on Glimesh") %></option>
                        </select>
                        <small id="locationHelp" class="form-text text-muted"><%= gettext("Please include relevant links in the notes section.") %></small>
                      </div>

                      <div class="form-group">
                        <label for="report_reason"><%= gettext("What has this user done wrong?")%></label>
                        <div class="form-check">
                          <input class="form-check-input" type="radio" name="report_reason" id="reportHateSpeech" value="hate-speech">
                          <label class="form-check-label" for="reportHateSpeech">
                            <%= gettext("Hate Speech") %>
                          </label>
                        </div>
                        <div class="form-check">
                          <input class="form-check-input" type="radio" name="report_reason" id="reportInappropriateContent" value="inappropriate-content">
                          <label class="form-check-label" for="reportInappropriateContent">
                            <%= gettext("Inappropriate Content") %>
                          </label>
                        </div>
                        <div class="form-check">
                          <input class="form-check-input" type="radio" name="report_reason" id="reportCopyrightInfringementOrLawViolation" value="copyright-infringement-or-law-violation">
                          <label class="form-check-label" for="reportCopyrightInfringementOrLawViolation">
                            <%= gettext("Copyright Infringement / Law Violation") %>
                          </label>
                        </div>
                        <div class="form-check">
                          <input class="form-check-input" type="radio" name="report_reason" id="reportOther" value="other">
                          <label class="form-check-label" for="reportOther">
                            <%= gettext("Other") %>
                          </label>
                        </div>
                      </div>


                      <div class="form-group mt-4">
                        <label for="reportNotes"><%= gettext("Notes") %></label>
                        <input type="text" class="form-control" name="notes" id="reportNotes" placeholder="<%= gettext("Other details you'd like to share") %>">
                      </div>

                      <button class="btn btn-danger btn-block mt-4"><%= gettext("Submit Report") %></button>
                      </form>
                    </div>

                </div>
            </div>
        </div>
      <% end %>
    <% end %>
    """
  end

  @impl true
  def mount(_params, %{"user_id_to_report" => reported_id, "user_token" => user_token}, socket) do
    maybe_user = Accounts.get_user_by_session_token(user_token)
    reported_user = Accounts.get_user!(reported_id)

    {:ok,
     assign(socket,
       reported_user: reported_user,
       user: maybe_user,
       show_button: !is_nil(maybe_user),
       show_report: false
     )}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       reported_user: nil,
       user: nil,
       show_button: false,
       show_report: false
     )}
  end

  @impl true
  def handle_event(
        "save",
        %{"report_reason" => report_reason, "location" => location, "notes" => notes},
        socket
      ) do
    {:ok, _} =
      Glimesh.Accounts.UserNotifier.deliver_user_report_alert(
        socket.assigns.user,
        socket.assigns.streamer,
        report_reason,
        location,
        notes
      )

    {:noreply,
     socket
     |> assign(:show_report, false)
     |> put_flash(:report_info, "Report submitted, thank you!")}
  end

  @impl true
  def handle_event("show_modal", _value, socket) do
    {:noreply, socket |> assign(:show_report, true)}
  end

  @impl true
  def handle_event("hide_modal", _value, socket) do
    {:noreply, socket |> assign(:show_report, false)}
  end
end
