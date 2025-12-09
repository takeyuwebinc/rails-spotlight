class UsesController < ApplicationController
  def index
    @items_by_category = UsesItem.published
                                 .active
                                 .ordered
                                 .group_by(&:category)
  end
end
