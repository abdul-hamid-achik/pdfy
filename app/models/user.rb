class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  has_many :pdf_templates, dependent: :destroy
  has_many :processed_pdfs, through: :pdf_templates
  
  def admin?
    admin
  end
end
