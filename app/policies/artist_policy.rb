class ArtistPolicy < ApplicationPolicy
  def index?
    user.super_admin? || user.artist_manager?
  end

  def create?
    puts "Policy: user=#{user.inspect}, record=#{record.inspect}"
    artist_record = user.artist&.persisted? ? user.artist : nil
    puts "Policy: super_admin?=#{user.super_admin?}, artist_manager?=#{user.artist_manager?}, artist?=#{user.artist?}, artist.nil?=#{artist_record.nil?}, artist=#{artist_record.inspect}"
    
    if user.super_admin? || user.artist_manager?
      puts "Policy: Allowing create for super_admin or artist_manager"
      return true
    end
    if user.artist? && (artist_record.nil? || record.user_id == user.id)
      puts "Policy: Allowing create for artist with no persisted artist record or matching user_id"
      return true
    end
    puts "Policy: Denying create"
    false
  end

  def update?
    return true if user.super_admin?
    return true if user.artist_manager? && record.manager_id == user.id
    return true if user.artist? && record.user_id == user.id
    false
  end

  def destroy?
    return true if user.super_admin?
    return true if user.artist_manager? && record.manager_id == user.id
    return true if user.artist? && record.user_id == user.id
    false
  end

  def csv_import?
    user.super_admin? ||  user.artist_manager?
  end

  def csv_export?
    user.super_admin? || user.artist_manager?
  end
  
  def assign_manager?
    user.super_admin?
  end

  def all_artists?
    user.artist? || user.artist_manager? || user.super_admin?
  end

  def my_artists?
    return false unless user
    user.artist_manager?
  end



  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.artist_manager?
        scope.where(manager_id: user.id)
      else
        scope.where(user_id:user.id)
      end
    end
  end
end
