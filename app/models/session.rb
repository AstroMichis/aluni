# One signed-in device. The id travels in a permanent signed cookie
# (Authentication#start_new_session_for); deleting the row signs that device
# out. updated_at is "last seen" (touched at most daily by resume_session).
class Session < ApplicationRecord
  belongs_to :user
end
