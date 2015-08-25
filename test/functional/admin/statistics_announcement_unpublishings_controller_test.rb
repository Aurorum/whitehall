require 'test_helper'

class Admin::StatisticsAnnouncementUnpublishingsControllerTest < ActionController::TestCase
  setup do
    @user = login_as(:gds_editor)
    @announcement = create(:statistics_announcement)
  end

  should_be_an_admin_controller

  view_test "GET :new renders a form" do
    get :new, statistics_announcement_id: @announcement

    assert_response :success
    assert_select "input[name='statistics_announcement[redirect_url]']"
  end

  test "POST :create with invalid params rerenders the form" do
    post :create, statistics_announcement_id: @announcement, statistics_announcement: {
      redirect_url: 'https://youtube.com'
    }

    assert_template :new
  end

  test "POST :create with valid params unpublishes the announcement" do
    redirect_url = 'https://www.test.alphagov.co.uk/example'
    post :create, statistics_announcement_id: @announcement, statistics_announcement: {
      redirect_url: redirect_url
    }

    @announcement.reload
    assert_redirected_to admin_statistics_announcement_url(@announcement)
    assert_equal redirect_url, @announcement.redirect_url
    assert @announcement.unpublished?
  end
end
