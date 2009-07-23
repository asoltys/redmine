require File.dirname(__FILE__) + '/../test_helper'
begin
  require 'mocha'
  
  class MercurialAdapterTest < Test::Unit::TestCase
    
    TEMPLATES_DIR = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATES_DIR
    TEMPLATE_NAME = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_NAME
    TEMPLATE_EXTENSION = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_EXTENSION
    
    REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/mercurial_repository'
    
    if File.directory?(REPOSITORY_PATH)  
      def test_hgversion
        to_test = { "0.9.5" => [0,9,5],
                    "1.0" => [1,0],
                    "1e4ddc9ac9f7+20080325" => nil,
                    "1.0.1+20080525" => [1,0,1],
                    "1916e629a29d" => nil}
        
        to_test.each do |s, v|
          test_hgversion_for(s, v)
        end
      end
      
      def test_template_path
        to_test = { [0,9,5] => "0.9.5",
                    [1,0] => "1.0",
                    [] => "1.0",
                    [1,0,1] => "1.0"}
        
        to_test.each do |v, template|
          test_template_path_for(v, template)
        end
      end

      def test_branches
        adapter = Redmine::Scm::Adapters::MercurialAdapter.new(REPOSITORY_PATH)
        assert_equal ['default','test_branch'], adapter.branches
      end
      
      def test_default_branch
        adapter = Redmine::Scm::Adapters::MercurialAdapter.new(REPOSITORY_PATH)
        assert_equal 'default', adapter.default_branch
      end

      def test_branch_entries
        adapter = Redmine::Scm::Adapters::MercurialAdapter.new(REPOSITORY_PATH)
        assert_equal 1, adapter.entries('sources','default').length
        assert_equal 2, adapter.entries('sources','test_branch').length
      end

      def test_branch_revisions
        adapter = Redmine::Scm::Adapters::MercurialAdapter.new(REPOSITORY_PATH)
        assert_equal 6, adapter.revisions('','default').length
        assert_equal 2, adapter.revisions('','test_branch').length
      end
    else
      puts "Mercurial test repository NOT FOUND. Skipping unit tests !!!"
      def test_fake; assert true end
    end
    
    private
    
    def test_hgversion_for(hgversion, version)
      Redmine::Scm::Adapters::MercurialAdapter.expects(:hgversion_from_command_line).returns(hgversion)
      adapter = Redmine::Scm::Adapters::MercurialAdapter
      assert_equal version, adapter.hgversion
    end
    
    def test_template_path_for(version, template)
      adapter = Redmine::Scm::Adapters::MercurialAdapter
      assert_equal "#{TEMPLATES_DIR}/#{TEMPLATE_NAME}-#{template}.#{TEMPLATE_EXTENSION}", adapter.template_path_for(version)
      assert File.exist?(adapter.template_path_for(version))
    end
  end
  
rescue LoadError
  def test_fake; assert(false, "Requires mocha to run those tests")  end
end
