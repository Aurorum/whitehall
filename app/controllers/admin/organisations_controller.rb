class Admin::OrganisationsController < Admin::BaseController
  before_filter :load_organisation, except: [:index, :new, :create]
  before_filter :enforce_permissions!, only: [:new, :create, :edit, :update]

  def index
    @organisations = Organisation.alphabetical
    @user_organisation = current_user.organisation
  end

  def new
    @organisation = Organisation.new
    build_organisation_classifications
  end

  def create
    @organisation = Organisation.new(organisation_params)
    if @organisation.save
      redirect_to admin_organisations_path
    else
      render :new
    end
  end

  def show
  end

  def people
    @ministerial_organisation_roles = @organisation.organisation_roles.joins(:role).
                                        merge(Role.ministerial).order(:ordering)
    @management_organisation_roles = @organisation.organisation_roles.joins(:role).
                                        merge(Role.management).order(:ordering)
    @traffic_commissioner_organisation_roles = @organisation.organisation_roles.joins(:role).
                                        merge(Role.traffic_commissioner).order(:ordering)
    @military_organisation_roles = @organisation.organisation_roles.joins(:role).
                                        merge(Role.military).order(:ordering)
    @special_representative_organisation_roles = @organisation.organisation_roles.joins(:role).
                                        merge(Role.special_representative).order(:ordering)
    @chief_professional_officer_roles = @organisation.organisation_roles.joins(:role).
                                        merge(Role.chief_professional_officer).order(:ordering)
  end

  def features
    @feature_list = @organisation.load_or_create_feature_list(params[:locale])

    filter_params = params.slice(:page, :type, :author, :organisation, :title).
      merge(state: 'published')
    @filter = Admin::EditionFilter.new(Edition, current_user, filter_params)
    @featurable_topical_events = TopicalEvent.active
    @featurable_offsite_links = @organisation.offsite_links

    if request.xhr?
      render partial: 'admin/feature_lists/search_results', locals: {feature_list: @feature_list}
    else
      render :features
    end
  end

  def edit
    build_organisation_classifications
    build_default_news_image
  end

  def update
    delete_absent_organisation_classifications
    if @organisation.update_attributes(organisation_params)
      redirect_to admin_organisation_path(@organisation)
    else
      render :edit
    end
  end

  def destroy
    @organisation.destroy
    redirect_to admin_organisations_path
  end

  private

  def enforce_permissions!
    case action_name
    when 'new', 'create'
      enforce_permission!(:create, Organisation)
    when 'edit', 'update'
      enforce_permission!(:edit, @organisation)
    end
  end

  def organisation_params
    params.require(:organisation).permit(
      :name, :acronym, :logo_formatted_name, :organisation_logo_type_id,
      :logo, :logo_cache, :organisation_brand_colour_id, :url,
      :organisation_type_key, :alternative_format_contact_email,
      :govuk_status, :govuk_closed_status, :closed_at, :organisation_chart_url,
      :foi_exempt, :ocpa_regulated, :public_meetings, :public_minutes,
      :regulatory_function, :important_board_members, :custom_jobs_url,
      :homepage_type, :political,
      superseding_organisation_ids: [],
      default_news_image_attributes: [:file, :file_cache],
      organisation_roles_attributes: [:id, :ordering],
      parent_organisation_ids: [],
      organisation_classifications_attributes: [
        :classification_id, :ordering, :id, :_destroy
      ],
      featured_links_attributes: [:title, :url, :_destroy, :id],
    )
  end

  def build_organisation_classifications
    n = @organisation.organisation_classifications.count
    @organisation.organisation_classifications.each.with_index do |ot, i|
      ot.ordering = i
    end
    (n...13).each do |i|
      @organisation.organisation_classifications.build(ordering: i)
    end
  end

  def build_default_news_image
    @organisation.build_default_news_image
  end

  def delete_absent_organisation_classifications
    return unless params[:organisation] &&
                  params[:organisation][:organisation_classifications_attributes]
    params[:organisation][:organisation_classifications_attributes].each do |p|
      if p[:classification_id].blank?
        p["_destroy"] = true
      end
    end
  end

  def load_organisation
    @organisation = Organisation.friendly.find(params[:id])
  end
end
