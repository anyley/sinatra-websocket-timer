require 'json'
require 'slim'
require 'faye/websocket'
require 'thread'
require 'sinatra/base'

module Timer

  class WebServer < Sinatra::Base
    enable :inline_templates
    get '/' do
      slim :index
    end
  end

  class Main
    def initialize(app=nil)
      @clients = []
      @web     = app

      Thread.new do
        while true do
          @clients.each { |ws| ws.send(JSON.generate({ time: Time.now.strftime('%d.%m.%Y %T') })) }
          sleep 1
        end
      end
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
        ws = Faye::WebSocket.new(env, nil, { ping: 15 })
        ws.on(:open) { puts 'open'; @clients << ws }
        ws.on(:close) { puts 'close'; @clients.delete(ws); ws = nil }
        ws.on(:message) { |event| p JSON.parse(event.data) }
        ws.rack_response
      else
        @web.call(env)
        # [101, {'Content-Type' => 'text/html'}, ['Hello']]
      end
    end
  end

end

use Timer::Main
run Timer::WebServer.new

__END__

@@ index
html
  h1 Timer
  div#root


@@ layout
doctype html
html
  head
    body
      == yield

@@ index
div#root

javascript:
  let ws = new WebSocket('ws://localhost:5000/');
  let timerListener = (response) => {
    document.getElementById('root').innerHTML = `<h1> ${JSON.parse(response.data).time} </h1>`;
  };

  timer = setInterval(function() {
    if (document.readyState == 'complete') {
      ws.onmessage = timerListener;
      clearInterval(timer);
    }
  }, 10);
