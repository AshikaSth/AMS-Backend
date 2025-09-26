class UserPolicy < ApplicationPolicy
  def index?
    user.super_admin?
  end

  def show?
    user.super_admin?
  end

  def unassigned_artists?
    user.super_admin? || user.artist_manager?
  end

  def create?
    user.super_admin?
  end

  def update?
    user.super_admin? ||  user.id == record.id
  end

  def destroy?
    user.super_admin? ||  user.id == record.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.artist_manager?
        scope.where(id: Artist.where(manager_id: user.id).pluck(:user_id))
      else
        scope.where(id:user.id)
      end
    end
  end
end
