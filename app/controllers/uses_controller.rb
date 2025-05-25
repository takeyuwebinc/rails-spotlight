class UsesController < ApplicationController
  def index
    @items_by_category = UsesItem.published
                                 .ordered
                                 .group_by(&:category)
  end
end
