require "rails_helper"

describe Accounts::OrganizationsController do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }

  def icon_upload(width: 512, height: 512, content_type: "image/png")
    file = Tempfile.new(["icon", ".png"])
    Vips::Image.black(width, height).write_to_file(file.path)
    Rack::Test::UploadedFile.new(file.path, content_type)
  end

  before do
    sign_in user.email_authentication
  end

  describe "PATCH #update" do
    it "attaches the icon to the organization" do
      patch :update, params: {id: organization.slug, accounts_organization: {icon: icon_upload}}

      expect(organization.reload.icon).to be_attached
      expect(response).to redirect_to(edit_accounts_organization_path(organization))
      expect(flash[:notice]).to eq("Organization was updated.")
    end

    it "replaces an existing icon" do
      organization.icon.attach(icon_upload)
      old_blob = organization.icon.blob

      patch :update, params: {id: organization.slug, accounts_organization: {icon: icon_upload(width: 1024, height: 1024)}}

      expect(organization.reload.icon).to be_attached
      expect(organization.icon.blob).not_to eq(old_blob)
    end

    it "does not attach an icon that is not a square" do
      patch :update, params: {id: organization.slug, accounts_organization: {icon: icon_upload(width: 512, height: 1024)}}

      expect(organization.reload.icon).not_to be_attached
      expect(response).to redirect_to(edit_accounts_organization_path(organization))
      expect(flash[:error]).to eq("the icon must be a square image.")
    end

    it "does not attach an icon with an unsupported format" do
      patch :update, params: {id: organization.slug, accounts_organization: {icon: icon_upload(content_type: "image/gif")}}

      expect(organization.reload.icon).not_to be_attached
      expect(flash[:error]).to eq("the file format is not supported.")
    end

    context "when the user is a viewer" do
      let(:user) { create(:user, :with_email_authentication, :as_viewer, member_organization: organization) }

      it "does not attach the icon" do
        patch :update, params: {id: organization.slug, accounts_organization: {icon: icon_upload}}

        expect(organization.reload.icon).not_to be_attached
        expect(flash[:error]).to eq("You are not authorized to perform this action.")
      end
    end

    context "when the user is only a viewer of the organization being updated" do
      let(:other_organization) { create(:organization) }

      before do
        create(:membership, :viewer, user:, organization: other_organization)
        allow(controller).to receive(:current_organization).and_return(organization)
      end

      it "does not attach the icon" do
        patch :update, params: {id: other_organization.slug, accounts_organization: {icon: icon_upload}}

        expect(other_organization.reload.icon).not_to be_attached
        expect(flash[:error]).to eq("You are not authorized to perform this action.")
      end
    end
  end

  describe "DELETE #remove_icon" do
    before do
      organization.icon.attach(icon_upload)
    end

    it "removes the icon from the organization" do
      delete :remove_icon, params: {id: organization.slug}

      expect(organization.reload.icon).not_to be_attached
      expect(response).to redirect_to(edit_accounts_organization_path(organization))
      expect(flash[:notice]).to eq("Icon removed.")
    end

    context "when the user is a viewer" do
      let(:user) { create(:user, :with_email_authentication, :as_viewer, member_organization: organization) }

      it "does not remove the icon" do
        delete :remove_icon, params: {id: organization.slug}

        expect(organization.reload.icon).to be_attached
        expect(flash[:error]).to eq("You are not authorized to perform this action.")
      end
    end
  end
end
