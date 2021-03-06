class ItemsController < ApplicationController
  before_action :set_item, only: [:buy, :pay, :show, :edit, :update, :destroy]
  before_action :set_category, only: [:index, :new, :show, :edit]
  before_action :login_in_user,  except: [:index, :show]
  before_action :correct_user, only: [:edit, :update, :destroy]
  before_action :my_item_check, only: [:buy, :pay]
  before_action :buy_item_check, only: [:buy, :pay]

  def buy
    @image = @item.images[0].image_url
    @seller = User.find(@item.seller_id)
    @card = Card.where(user_id: current_user.id).first if Card.where(user_id: current_user.id).present?
    if @card.blank?
      flash[:notice] = '購入にはクレジットカード登録が必要です'
      redirect_to new_card_url
    else
      Payjp.api_key = Rails.application.credentials.payjp[:secret_key]
      customer = Payjp::Customer.retrieve(@card.customer_id)
      @card_info = customer.cards.retrieve(customer.default_card)
      @card_brand = @card_info.brand
      @exp_month = @card_info.exp_month.to_s
      @exp_year = @card_info.exp_year.to_s.slice(2,3)

      case @card_brand
      when "Visa"
        @card_image = "credit-visa.svg"
      when "JCB"
        @card_image = "credit-jcb.svg"
      when "MasterCard"
        @card_image = "credit-master-card.svg"
      when "American Express"
        @card_image = "credit-american_express.svg"
      when "Diners Club"
        @card_image = "credit-dinersclub.svg"
      when "Discover"
        @card_image = "credit-discover.svg"
      when "Saison"
        @card_image = "credit-saison-card.svg"
      end
    end
  end

  def pay
    @card = Card.where(user_id: current_user.id).first if Card.where(user_id: current_user.id).present?
    if @card.blank?
      redirect_to new_card_url
      flash[:notice] = '購入にはクレジットカード登録が必要です'
    else
      Payjp.api_key = Rails.application.credentials.payjp[:secret_key]
      Payjp::Charge.create(
      amount: @item.price,
      customer: @card.customer_id,
      currency: 'jpy',
      )
      if @item.update(buyer_id: current_user.id)
        flash[:notice] = '購入しました'
        redirect_to root_url
      else
        flash[:notice] = '購入に失敗しました'
        redirect_to item_url(@item)
      end
    end
  end

  def index
    @items = Item.order(id: :desc).where(buyer_id:nil)
    @images = Image.includes(:item)
  end

  def new
    @item = Item.new
    @item.images.new
    @category_parent_array = ["---"]
    @category_parent_array.concat(@parents.pluck(:name))
  end

  def get_category_children
    @category_children = Category.find_by(name: "#{params[:parent_name]}", ancestry: nil).children
  end

  def get_category_grandchildren
    @category_grandchildren = Category.find("#{params[:child_id]}").children
  end

  def create
    @item = Item.new(item_params)
    if @item.save
      flash[:notice] = '出品しました'
      redirect_to root_url
    else
      flash[:notice] = '必須項目を入力してください'
      redirect_to new_item_url
    end
  end

  def show
    @items = Item.all
    @images = @item.images
    @image = @item.images[0].image_url
    @seller = User.find(@item.seller_id)
    @comment = Comment.new
    @comments = @item.comments.includes(:user)
  end

  def edit
    @items = Item.all
    @images = @item.images
    @image = @item.images[0].image_url
    @seller = User.find(@item.seller_id)
    grandchild_category = @item.category
    child_category = grandchild_category.parent
    @category_parent_array = ["---"]
    @category_parent_array.concat(@parents.pluck(:name))
    @category_children_array = Category.where(ancestry: child_category.ancestry)
    @category_grandchildren_array = Category.where(ancestry: grandchild_category.ancestry)
  end

  def update
    if user_signed_in? && current_user.id == @item.seller_id
      if @item.update(item_params)
        flash[:notice] = '商品の情報を編集しました'
        redirect_to item_path
      else
        flash[:notice] = '必須項目を入力してください'
        redirect_to edit_item_path
      end
    end
  end

  def destroy
    if user_signed_in? && current_user.id == @item.seller_id
      if @item.destroy
        flash[:notice] = '商品を削除しました'
        redirect_to root_url
      else
        flash[:notice] = '削除出来ませんでした'
        redirect_to item_url
      end
    end
  end

  private

  def set_item
    @item = Item.find(params[:id])
  end

  def set_category
    @parents = Category.where(ancestry: nil)
  end

  def login_in_user
    unless user_signed_in?
      flash[:alert] = "ログインしてください"
      redirect_to sign_in_url
    end
  end

  def correct_user
    unless current_user.id == @item.seller_id
    flash[:alert] = "アクセスできません"
    redirect_to root_url
    end
  end

  def item_params
    params.require(:item).permit(:title, :content, :price, :status_id, :prefecture_id, :delivery_days_id, :delivery_charge_id, :category_id, :delivery_method_id, :seller_id, images_attributes: [:image, :_destroy, :id]).merge(seller_id: current_user.id)
  end

  def my_item_check
    if user_signed_in? && current_user.id == @item.seller_id
      flash[:alert] = "自分で出品した商品は購入出来ません。"
      redirect_to root_url
    end
  end

  def buy_item_check
    if @item.buyer_id.present?
      flash[:alert] = "購入済みの商品です。"
      redirect_to root_url
    end
  end

end
