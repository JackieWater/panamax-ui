require 'spec_helper'

describe TemplatesController do

  let(:fake_user) { double(:fake_user) }
  let(:fake_app) { double(:fake_app, id: 7, write_attributes: true, save: true) }
  let(:fake_types) { double(:fake_types) }
  let(:fake_template) { double(:fake_template, id: 1) }
  let(:fake_template_form) do
    double(:fake_template_form, repo: 'foo/bar', save: true, app_id: 7, documentation: 'some docs')
  end

  before do
    allow(Template).to receive(:find).and_return(fake_template)
    allow(User).to receive(:find).and_return(fake_user)
    allow(TemplateForm).to receive(:new).and_return(fake_template_form)
    allow(App).to receive(:find).and_return(fake_app)
    allow(Type).to receive(:all).and_return(fake_types)
    allow(fake_user).to receive(:github_access_token_present?)
    allow(fake_user).to receive(:has_valid_github_creds?)
    allow(fake_user).to receive(:has_invalid_github_creds?)
  end

  describe 'GET #new' do
    it 'hydrates the template form with a user, types, and app_id' do
      expect(TemplateForm).to receive(:new).with(
        types: fake_types,
        user: fake_user,
        app: fake_app
      )
      get :new, app_id: 7
    end

    it 'renders the new view' do
      get :new
      expect(response).to render_template :new
    end

    it 'looks up and assign the user' do
      get :new
      expect(assigns(:user)).to eq fake_user
    end

    it 'assigns a template form' do
      get :new
      expect(assigns(:template_form)).to eq fake_template_form
    end

    context 'when an app cannot be found' do
      before do
        allow(App).to receive(:find).and_raise(ActiveResource::ResourceNotFound.new(double('err', code: '404')))
      end

      it 'redirects to the apps page with a flash message' do
        get :new
        expect(flash[:alert]).to eq 'could not find application'
        expect(response).to redirect_to(apps_path)
      end
    end

    context 'when the user comes in for the first time' do
      before do
        allow(fake_user).to receive(:has_valid_github_creds?).and_return(false)
        allow(fake_user).to receive(:has_invalid_github_creds?).and_return(false)
      end

      it 'renders the new view without any error message' do
        get :new
        expect(flash[:alert]).to be_nil
        expect(response).to render_template :new
      end

    end

    context 'when user github creds are not valid' do
      expected_flash_msg = "Your token may be malformed, expired or is not scoped correctly."
      before do
        allow(fake_user).to receive(:has_invalid_github_creds?).and_return(true)
        allow(fake_user).to receive(:has_valid_github_creds?).and_return(false)
      end

      it 'renders the new view with a flash error message' do
        get :new
        expect(flash[:alert]).to include(expected_flash_msg)
        expect(response).to render_template :new
      end

    end

  end

  describe 'POST #create' do

    let(:create_params) do
      {
        'name' => 'My template',
        'repo' => 'foo/bar',
        'app_id' => '7',
        'documentation' => 'some docs'
      }
    end

    it 'assigns a template form with the supplied parameters' do
      expect(TemplateForm).to receive(:new).with(create_params).and_return(fake_template_form)
      post :create, 'template_form' => create_params
      expect(assigns(:template_form)).to eq fake_template_form
    end

    it 'updates the app with the new documentation' do
      expect(App).to receive(:find).with(fake_template_form.app_id).and_return(fake_app)
      expect(fake_app).to receive(:write_attributes)
                          .with(documentation: fake_template_form.documentation)
                          .and_return(true)
      expect(fake_app).to receive(:save).and_return(true)
      post :create, 'template_form' => create_params
    end

    context 'when saving is successful' do
      before do
        allow(fake_template_form).to receive(:save).and_return(true)
      end

      it 'sets a successful flash message' do
        post :create, 'template_form' => create_params
        expect(flash[:success]).to eq 'Template successfully created.'
      end

      it 'redirects to the applications path' do
        post :create, 'template_form' => create_params
        expect(response).to redirect_to apps_path
      end

      it 'adds the repo to the template_repo sources' do
        expect(TemplateRepo).to receive(:find_or_create_by_name).with(create_params['repo'])
        post :create, 'template_form' => create_params
      end

    end

    context 'when saving is not successful' do
      before do
        allow(fake_template_form).to receive(:save).and_return(false)
        allow(fake_template_form).to receive(:errors).and_return(['some stuff'])
        allow(fake_template_form).to receive(:user=).and_return(true)
        allow(fake_template_form).to receive(:types=).and_return(true)
      end

      it 'looks up and assigns the user' do
        post :create
        expect(assigns(:user)).to eq fake_user
      end

      it 're-renders the templates#new view' do
        post :create, 'template_form' => create_params
        expect(response).to render_template :new
      end

      it 'does not add the repo to the template_repo sources' do
        expect(TemplateRepo).to_not receive(:find_or_create_by_name)
        post :create, 'template_form' => create_params
      end

    end

    context 'for template_repo' do
      it 'invokes create unless repo already exists' do
        expect(TemplateRepo).to_not receive(:create).with(name: 'user/publicrepo')
        post :create, name: 'user/publicrepo'
      end
    end
  end

  describe 'GET #details' do
    it 'assigns the template' do
      get :details, id: 1
      expect(assigns(:template)).to eq fake_template
      expect(assigns(:template).id).to eq 1
    end
    it 'renders the details view' do
      get :details, id: 1
      expect(response).to render_template :details
    end
    it 'renders without a layout' do
      get :details, id: 1
      expect(response).to render_template(layout: nil)
    end
  end
end
