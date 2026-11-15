# frozen_string_literal: true

# My team: a task's title (the sample's come from the locale files).
module StaffHelper
  def task_title(task) = task["title"].presence || t("staff.sample_tasks.#{task["title_key"]}")
end
