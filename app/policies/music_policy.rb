class MusicPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    user.artist?
  end

  def all_musics?
    user.artist? || user.artist_manager? || user.super_admin?
  end

  def update?
    return true if user.super_admin?
    return false if user.artist_manager?
    return false unless record.creator 
    user.artist? && record.creator.user_id == user.id
  end

  def destroy?
    user.super_admin? || user.artist? && record.creator.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
