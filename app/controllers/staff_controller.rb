# My team (section 4): the people who work on the farm, their tasks, and what
# each role can do.
class StaffController < ApplicationController
  include FarmPreview

  def show
  end

  def tasks
  end

  def roles
  end

  def create_member
    save_and_return Staff::SaveMemberService.call(data: draft.data, **member_params), fallback: menu_staff_path
  end

  def update_member
    save_and_return Staff::SaveMemberService.call(data: draft.data, id: params[:id], **member_params), fallback: menu_staff_path
  end

  def destroy_member
    save_and_return Staff::RemoveMemberService.call(data: draft.data, id: params[:id]), fallback: menu_staff_path
  end

  def create_task
    save_and_return Staff::SaveTaskService.call(data: draft.data, **params.fetch(:task, {}).permit(:title, :field, :member, :due).to_h.symbolize_keys),
                    fallback: tasks_menu_staff_path
  end

  def update_task
    save_and_return Staff::SaveTaskService.call(data: draft.data, id: params[:id], done: params[:done]), fallback: tasks_menu_staff_path
  end

  def destroy_task
    save_and_return Staff::RemoveTaskService.call(data: draft.data, id: params[:id]), fallback: tasks_menu_staff_path
  end

  private

  def member_params
    params.fetch(:member, {}).permit(:name, :role, fields: []).to_h.symbolize_keys
  end
end
