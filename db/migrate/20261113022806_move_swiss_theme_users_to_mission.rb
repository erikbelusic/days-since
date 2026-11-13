# The Swiss Report theme was replaced by Mission Control. Move anyone who
# picked it so their saved theme stays valid.
class MoveSwissThemeUsersToMission < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE users SET theme = 'mission' WHERE theme = 'swiss'"
  end

  def down
    execute "UPDATE users SET theme = 'swiss' WHERE theme = 'mission'"
  end
end
