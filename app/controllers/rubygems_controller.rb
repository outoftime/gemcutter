class RubygemsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => :create
  before_filter :authenticate_with_api_key, :only => :create
  before_filter :verify_authenticated_user, :only => :create
  before_filter :redirect_to_root, :only => [:edit, :update], :unless => :signed_in?
  before_filter :find_gem, :only => [:edit, :update, :show, :version]
  before_filter :load_gem, :only => [:edit, :update]

  def index
    params[:offset] ||= 0
    respond_to do |format|
      format.html do
        params[:letter] = 'A' unless params[:letter]
        params[:letter].upcase! if params[:letter].size == 1
        @gems = Rubygem.name_starts_with(params[:letter]).by_name(:asc).with_versions.paginate(:page => params[:page])
      end
      format.atom do
        @versions = Version.published(20)
        render 'versions/feed'
      end
      format.xml  { render :xml  => Rubygem.by_name(:asc).with_versions.all(:limit => 30, :offset => params[:offset]) }
      format.json { render :json => Rubygem.by_name(:asc).with_versions.all(:limit => 30, :offset => params[:offset]) }
      # format.yaml { render :text => Rubygem.by_name(:asc).with_versions.all(:limit => 30, :offset => params[:offset]).to_yaml, :content_type => 'text/yaml' }
    end
  end

  def show
    respond_to do |format|
      format.html do
        @latest_version = @rubygem.versions.latest
      end
      if @rubygem.try(:hosted?)
        format.json { render :json => @rubygem }
        format.xml  { render :xml  => @rubygem  }
        format.yaml { render :text => @rubygem.to_yaml, :content_type => 'text/yaml' }
      else
        format.json { render :json => "Not hosted here.", :status => :not_found }
        format.xml  { render :xml  => "Not hosted here.", :status => :not_found }
        format.yaml { render :text => "Not hosted here.", :status => :not_found, :content_type => 'text/yaml' }
      end
    end
  end

  def edit
  end

  def update
    if @linkset.update_attributes(params[:linkset])
      redirect_to rubygem_path(@rubygem)
      flash[:success] = "Gem links updated."
    else
      render :edit
    end
  end

  def create
    gemcutter = Gemcutter.new(current_user, request.body)
    gemcutter.process
    render :text => gemcutter.message, :status => gemcutter.code
  end
  
  def version
    render :text => @rubygem.versions.current.number
  end

  protected
    def find_gem
      @rubygem = Rubygem.find_by_name(params[:id])
      if @rubygem.blank?
        respond_to do |format|
          format.html do
            render :file => 'public/404.html'
          end
          format.json { render :text => "This rubygem could not be found.", :status => :not_found }
          format.xml { render :text => "This rubygem could not be found.", :status => :not_found }
          format.yaml { render :text => "This rubygem could not be found.", :status => :not_found, :content_type => 'text/yaml' }
        end
      end
    end

    def load_gem
      if !@rubygem.owned_by?(current_user)
        flash[:warning] = "You do not have permission to edit this gem."
        redirect_to root_url
      end

      @linkset = @rubygem.linkset
    end
end
