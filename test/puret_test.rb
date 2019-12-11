require 'test_helper'

describe 'puret' do
  before do
    setup_db
    I18n.config.available_locales = [:de, :en, :sv]
    I18n.locale = I18n.default_locale = :en
    Post.create(:title => 'English title')
  end

  after do
    teardown_db
  end

  it "should have the correct database setup" do
    assert_equal 1, Post.count
  end

  it "allow translation" do
    I18n.locale = :de
    Post.first.update_attribute :title, 'Deutscher Titel'
    assert_equal 'Deutscher Titel', Post.first.title
    I18n.locale = :en
    assert_equal 'English title', Post.first.title
  end
 
  it "assert fallback to default locale" do
    post = Post.first
    I18n.locale = :sv
    post.title = 'Svensk titel'
    I18n.locale = :en
    assert_equal 'English title', post.title
    I18n.locale = :de
    assert_equal 'English title', post.title
  end
 
  it "assert fallback to saved default locale defined on instance" do
    post = Post.first
    def post.default_locale() :sv; end
    assert_equal :sv, post.puret_default_locale
    I18n.locale = :sv
    post.title = 'Svensk titel'
    post.save!
    I18n.locale = :en
    assert_equal 'English title', post.title
    I18n.locale = :de
    assert_equal 'Svensk titel', post.title
  end
 
  it "assert fallback to saved default locale defined on class level" do
    post = Post.first
    def Post.default_locale() :sv; end
    assert_equal :sv, post.puret_default_locale
    I18n.locale = :sv
    post.title = 'Svensk titel'
    post.save!
    I18n.locale = :en
    assert_equal 'English title', post.title
    I18n.locale = :de
    assert_equal 'Svensk titel', post.title
  end

  it "assert separate fallback for each attribute" do
    post = Post.first
    I18n.locale = :de
    post.text = 'Deutsche text'
    post.save!
    I18n.locale = :sv
    assert_equal 'English title', post.title
    assert_equal 'Deutsche text', post.text
  end
 
  it "post has_many translations" do
    assert_equal PostTranslation, Post.first.translations.first.class
  end
 
  it "translations are deleted when parent is destroyed" do
    I18n.locale = :de
    Post.first.update_attribute :title, 'Deutscher Titel'
    assert_equal 2, PostTranslation.count
    
    Post.destroy_all
    assert_equal 0, PostTranslation.count
  end
  
  it 'validates_presence_of should work' do
    post = Post.new
    assert_equal false, post.valid?
    
    post.title = 'English title'
    assert_equal true, post.valid?
  end

  it 'temporary locale switch should not clear changes' do
    I18n.locale = :de
    post = Post.first
    post.text = 'Deutscher Text'
    assert !post.title.blank?
    assert_equal 'Deutscher Text', post.text
  end

  it 'temporary locale switch should work like expected' do
    post = Post.new
    post.title = 'English title'
    I18n.locale = :de
    post.title = 'Deutscher Titel'
    post.save
    assert_equal 'Deutscher Titel', post.title
    I18n.locale = :en
    assert_equal 'English title', post.title
  end

  it 'translation model should validate presence of model' do
    t = PostTranslation.new
    t.valid?
    refute_nil t.errors[:post]
  end

  it 'translation model should validate presence of locale' do
    t = PostTranslation.new
    t.valid?
    refute_nil t.errors[:locale]
  end

  it 'translation model should validate uniqueness of locale in model scope' do
    post = Post.first
    t1 = PostTranslation.new :post => post, :locale => "de"
    t1.save!
    t2 = PostTranslation.new :post => post, :locale => "de"
    refute_nil t2.errors[:locale]
  end

  it 'model should provide attribute_before_type_cast' do
    assert_equal Post.first.title, Post.first.title_before_type_cast
  end
end
