# frozen_string_literal: true

module Reader
  class App
    get '/groups' do
      json []
    end

    post '/groups' do
      status 501
      json error: 'not implemented'
    end

    delete '/groups/:id' do
      status 501
      json error: 'not implemented'
    end

    post '/groups/:id/feeds' do
      status 501
      json error: 'not implemented'
    end
  end
end
