require "./pars3k/*"

module Pars3k
  NON_EXPRESSION_TYPES = ["Assign", "TypeNode", "Splat", "Union", "UninitializedVar", "TypeDeclaration", "Generic", "ClassDef", "Def", "VisibilityModifier", "MultiAssign"]

  macro do_parse(body)
    {% if NON_EXPRESSION_TYPES.includes? body[body.size - 1].class_name %}
      {{body[body.size - 1].raise "expected last operation in monad to be an expression, got a '#{body[body.size - 1].class_name}'"}}
    {% end %}

    ({{body[0].args[0]}}).bind do |{{body[0].receiver}}|
    {% for i in 1...body.size - 1 %}
      {% if body[i].class_name == "Assign" %}
          {{body[i].target}} = {{body[i].value}}
      {% else %}
        {% if body[i].class_name == "Call" && body[i].name == "<=" %}
          ({{body[i].args[0]}}).bind do |{{body[i].receiver}}|
        {% elsif NON_EXPRESSION_TYPES.includes? body[i].class_name %}
          {{body[i].raise "expected operation '<=' or '=', got '#{body[i].name}'"}}
        {% else %}
          {{body[i]}}
        {% end %}
      {% end %}
    {% end %}
      {{body[body.size - 1]}}
    {% for i in 1...body.size - 1 %}
      {% if body[i].class_name == "Call" && body[i].name == "<=" %}
        end
      {% end %}
    {% end %}
    end
  end
end

