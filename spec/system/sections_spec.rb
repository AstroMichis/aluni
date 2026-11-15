require "rails_helper"

RSpec.describe "Menu sections 2 to 5", type: :system do
  before { driven_by(:cuprite) }

  it "shows a day's temperature under the pointer and with the arrow keys" do
    visit menu_weather_path(locale: "en")

    find("#chart-temperature .chart__svg").hover
    expect(page).to have_css("#chart-temperature .chart__tooltip:not([hidden])", wait: 5)
    expect(find("#chart-temperature .chart__tooltip [data-part=value]").text).to include("°C")

    find("#chart-rain .chart__svg").send_keys(:right)
    expect(page).to have_css("#chart-rain .chart__tooltip:not([hidden])", text: "mm")
    expect_no_server_errors!
  end

  it "completes a task in place" do
    visit tasks_menu_staff_path(locale: "en")

    within(".task", text: I18n.t("staff.sample_tasks.scout")) { find(".task__check").click }
    expect(page).to have_css(".task.task--done", text: I18n.t("staff.sample_tasks.scout"), wait: 5)
  end
end
