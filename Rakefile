%w{ rubygems bundler find rake/testtask }.each { |lib| require lib }

Dir.glob('lib/tasks/*.rake').each { |r| load r}

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test
