module OrganizationsHelper
  def can_current_user_edit_role?(member)
    member_role = member.role_for(current_organization)

    ((current_user_role == "owner" && member_role.in?(["developer", "viewer"])) ||
     (current_user_role == "developer" && member_role == "viewer")) &&
      current_user.id != member.id
  end

  def available_roles_for_member(member_role)
    (member_role == "viewer") ? Accounts::Membership.allowed_roles : Accounts::Membership.all_roles
  end

  def can_current_user_remove_member?(member)
    return false if current_user.id == member.id  # Users can't remove themselves
    return false if current_user_role != Accounts::Membership.roles[:owner]
    true
  end
end
