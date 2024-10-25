module OrganizationsHelper
  def can_edit_user_role?(current_user, member, current_organization)
    user_role = current_user.role_for(current_organization)
    member_role = member.role_for(current_organization)

    ((user_role == "owner" && member_role.in?(["developer", "viewer"])) ||
     (user_role == "developer" && member_role == "viewer")) &&
      current_user.id != member.id
  end

  def available_roles_for_member(member_role)
    (member_role == "viewer") ? Accounts::Membership.allowed_roles : Accounts::Membership.all_roles
  end
end
