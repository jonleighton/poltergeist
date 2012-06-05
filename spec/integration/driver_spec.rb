require 'spec_helper'
require 'capybara/spec/driver'
require 'image_size'

module Capybara::Poltergeist
  describe Driver do
    before do
      @driver = TestSessions::Poltergeist.driver
    end

    it_should_behave_like "driver"
    it_should_behave_like "driver with javascript support"
    it_should_behave_like "driver with frame support"
    it_should_behave_like "driver with cookies support"

    it 'should support a custom phantomjs path' do
      file = POLTERGEIST_ROOT + '/spec/support/custom_phantomjs_called'
      path = POLTERGEIST_ROOT + '/spec/support/custom_phantomjs'

      FileUtils.rm_f file

      driver  = Capybara::Poltergeist::Driver.new(nil, :phantomjs => path)
      driver.browser

      # If the correct custom path is called, it will touch the file. We allow at
      # least 10 secs for this to happen before failing.

      tries = 0
      until File.exist?(file) || tries == 100
        sleep 0.1
        tries += 1
      end

      File.exist?(file).should == true
    end

    it 'should raise an error and restart the client, if the client dies while executing a command' do
      lambda { @driver.browser.command('exit') }.should raise_error(DeadClient)
      @driver.visit('/')
      @driver.body.should include('Hello world')
    end

    it 'should have a viewport size of 1024x768 by default' do
      @driver.visit('/')
      @driver.evaluate_script('[window.innerWidth, window.innerHeight]').should == [1024, 768]
    end

    it 'should allow the viewport to be resized' do
      begin
        @driver.visit('/')
        @driver.resize(200, 400)
        @driver.evaluate_script('[window.innerWidth, window.innerHeight]').should == [200, 400]
      ensure
        @driver.resize(1024, 768)
      end
    end

    it 'should support rendering the page' do
      file = POLTERGEIST_ROOT + '/spec/tmp/screenshot.png'
      FileUtils.rm_f file
      @driver.visit('/')
      @driver.render(file)
      File.exist?(file).should == true
    end

    it 'should support rendering the whole of a page that goes outside the viewport' do
      file = POLTERGEIST_ROOT + '/spec/tmp/screenshot.png'
      @driver.visit('/poltergeist/long_page')
      @driver.render(file)

      File.open(file, 'rb') do |f|
        ImageSize.new(f.read).size.should ==
          @driver.evaluate_script('[window.innerWidth, window.innerHeight]')
      end

      @driver.render(file, :full => true)

      File.open(file, 'rb') do |f|
        ImageSize.new(f.read).size.should ==
          @driver.evaluate_script('[document.documentElement.clientWidth, document.documentElement.clientHeight]')
      end
    end

    it 'should support executing multiple lines of javascript' do
      @driver.execute_script <<-JS
        var a = 1
        var b = 2
        window.result = a + b
      JS
      @driver.evaluate_script("result").should == 3
    end

    it 'should operate a timeout when communicating with phantomjs' do
      begin
        prev_timeout = @driver.timeout
        @driver.timeout = 0.001
        lambda { @driver.browser.command 'noop' }.should raise_error(TimeoutError)
      ensure
        @driver.timeout = prev_timeout
      end
    end

    it 'supports quitting the session' do
      driver = Capybara::Poltergeist::Driver.new(nil)
      pid    = driver.client_pid

      Process.kill(0, pid).should == 1
      driver.quit

      begin
        Process.kill(0, pid)
      rescue Errno::ESRCH
      else
        raise "process is still alive"
      end
    end

    context 'javascript errors' do
      it 'propagates a Javascript error inside Poltergeist to a ruby exception' do
        expect { @driver.execute_script "omg" }.to raise_error(BrowserError)

        begin
          @driver.execute_script "omg"
        rescue BrowserError => e
          e.message.should include("omg")
          e.message.should include("ReferenceError")
        else
          raise "BrowserError expected"
        end
      end

      it 'propagates a Javascript error on the page to a ruby exception' do
        @driver.execute_script "setTimeout(function() { omg }, 0)"
        sleep 0.01
        expect { @driver.execute_script "" }.to raise_error(JavascriptError)

        begin
          @driver.execute_script "setTimeout(function() { omg }, 0)"
          sleep 0.01
          @driver.execute_script ""
        rescue JavascriptError => e
          e.message.should include("omg")
          e.message.should include("ReferenceError")
        else
          raise "expected JavascriptError"
        end
      end

      it "doesn't re-raise a Javascript error if it's rescued" do
        begin
          @driver.execute_script "setTimeout(function() { omg }, 0)"
          sleep 0.01
          @driver.execute_script ""
        rescue JavascriptError
        else
          raise "expected JavascriptError"
        end

        # should not raise again
        @driver.evaluate_script("1+1").should == 2
      end
    end

    describe 'status code support', :status_code_support => true do
      it 'should determine status from the simple response' do
        @driver.visit('/poltergeist/500')

        @driver.status_code.should == 500
      end

      it 'should determine status code when the page has a few resources' do
        @driver.visit('/poltergeist/with_different_resources')

        @driver.status_code.should == 200
      end

      it 'should determine status code even after redirect' do
        @driver.visit('/poltergeist/redirect')

        @driver.status_code.should == 200
      end
    end
  end
end
