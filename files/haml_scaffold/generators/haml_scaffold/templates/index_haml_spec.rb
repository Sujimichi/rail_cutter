require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../../spec_helper'

describe "/<%= name.pluralize %>/index.<%= default_file_extension %>" do
  before do
<% [98,99].each do |id| -%>
    <%= file_name %>_<%= id %> = mock_model(<%= singular_name.capitalize %>)
<% for attribute in attributes -%>
    <%= file_name %>_<%= id %>.should_receive(:<%= attribute.name %>).and_return(<%= attribute.default_value %>)
<% end -%><% end %>
    assigns[:<%= file_name.pluralize %>] = [<%= file_name %>_98, <%= file_name %>_99]
  end

  it "should render list of <%= table_name %>" do
    render "/<%= name.pluralize %>/index.<%= default_file_extension %>"
  end
end
