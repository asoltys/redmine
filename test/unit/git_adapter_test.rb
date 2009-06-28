require File.dirname(__FILE__) + '/../test_helper'
begin
  class GitAdapterTest < Test::Unit::TestCase
    REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/git_repository'

    def setup
      @adapter = Redmine::Scm::Adapters::GitAdapter.new(REPOSITORY_PATH)
    end

    def test_branches
      assert_equal @adapter.branches.map{|b| b.name}, ['master', 'test_branch']
    end
  end
rescue LoadError
  def test_fake; assert(false, "Requires mocha to run those tests")  end
end
