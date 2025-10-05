class MusicPolicy < ApplicationPolicy
 def index?
    user.super_admin? || artist_member?
  end

  def show?
    user.super_admin? || artist_member?
  end

  def all_musics?
    user.artist? || user.artist_manager? || user.super_admin?
  end

  def create?
    user.artist?
  end

  def update?
    user.super_admin? || artist_member?
  end

  def destroy?
    user.super_admin? || (user.artist? && artist_member?)
  end

private

  def artist_member?
    return false unless user.artist.present?
    record.artists.exists?(id: user.artist.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin? || user.artist_manager?
        scope.all
      elsif user.artist?
        scope.joins(:artists).where(artists: { id: user.artist.id }).distinct
      else
        scope.none
      end
    end
  end
end
