class GenrePolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def update?
    user.super_admin? 

  def destroy?
    user.super_admin? 
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
