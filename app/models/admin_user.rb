# frozen_string_literal: true

# AdminUser model
class AdminUser < ApplicationRecord
  self.implicit_order_column = "created_at"

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
end
