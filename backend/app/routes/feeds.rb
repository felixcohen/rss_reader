# frozen_string_literal: true

module Reader
  class App
    get '/feeds' do
      json []
    end

    post '/feeds' do
      status 501
      json error: 'not implemented'
    end

    delete '/feeds/:id' do
      status 501
      json error: 'not implemented'
    end

    post '/feeds/import' do
      status 501
      json error: 'not implemented'
    end

    get '/feeds/export' do
      status 501
      json error: 'not implemented'
    end
  end
end
