# frozen_string_literal: true

module Reader
  class App
    get '/items' do
      json []
    end

    get '/items/all' do
      json []
    end

    patch '/items/:id' do
      status 501
      json error: 'not implemented'
    end

    post '/items/mark-all-read' do
      status 501
      json error: 'not implemented'
    end
  end
end
