module Matcheadores
  def val(un_valor)
    MatcherVal.new(un_valor)
  end

  def type(un_tipo)
    MatcherType.new(un_tipo)
  end

  def duck(*metodos)
    MatcherDuckTyping.new(*metodos)
  end

  def list(una_lista, *condicion)
    MatcherList.new(una_lista, *condicion)
  end
end

class Object
  include Matcheadores
  def matches?(un_objeto, &bloque)
    pattern_context = PatternMatchingContext.new(un_objeto)
    pattern_context.instance_eval &bloque
    pattern_context.matchear
  end
end

module Matcher
  def and(*matchers)
    MatcherAndCombinator.new(self, *matchers)
  end

  def or(*matchers)
    MatcherOrCombinator.new(self, *matchers)
  end

  def not
    MatcherNotCombinator.new(self)
  end

  def bindear(*) end
end

class Symbol
  include Matcher
  def call(*)
    true
  end

  def bindear(un_objeto, diccionario)
    diccionario[self] = un_objeto
  end

  def if(&bloque)
    MatcherIf.new(self, &bloque)
  end
end

module Bindea
  def initialize(un_matcher, *matchers)
    @matchers = matchers
    @matchers << un_matcher
  end

  def bindear(un_objeto, diccionario)
    @matchers.each {|matcher| matcher.bindear(un_objeto, diccionario)}
  end
end

class MatcherAndCombinator
  include Matcher
  include Bindea
  def call(un_objeto)
    @matchers.all? {|otro_matcher| otro_matcher.call(un_objeto)}
  end
end

class MatcherOrCombinator
  include Matcher
  include Bindea
  def call(un_objeto)
    @matchers.any? {|otro_matcher| otro_matcher.call(un_objeto)}
  end
end

class MatcherNotCombinator
  include Matcher
  def initialize(matcher)
    @matcher = matcher
  end

  def call(un_objeto)
    !@matcher.call(un_objeto)
  end
end

class MatcherIf
  include Matcher
  def initialize(un_simbolo, &bloque)
    @simbolo = un_simbolo
    @bloque = bloque
  end

  def call(objeto_matcheable)
    objeto_matcheable.instance_eval(&@bloque)
  end

  def bindear(objeto_matcheable, diccionario)
    diccionario[@simbolo] = objeto_matcheable
  end
end

class MatcherVal
  include Matcher
  def initialize(un_valor)
    @valor = un_valor
  end

  def call(un_valor)
    @valor == un_valor
  end
end

class MatcherType
  include Matcher
  def initialize(un_tipo)
    @tipo = un_tipo
  end

  def call(un_objeto)
    un_objeto.is_a? @tipo
  end
end

class MatcherDuckTyping
  include Matcher
  def initialize(*metodos)
    @metodos = metodos
  end

  def call(un_objeto)
    @metodos.all? {|un_metodo| un_objeto.respond_to?(un_metodo)}
  end
end

class MatcherList
  include Matcher
  def initialize(una_lista, condicion = true)
    @matchers = una_lista.map {|elem| es_matcher(elem) ? elem : val(elem)}
    @condicion = condicion
  end

  def es_matcher(un_objeto)
    un_objeto.class.ancestors.include? Matcher
  end

  def comparar_listas(lista)
    lista.all? {|un_matcher, otro_valor| un_matcher.call(otro_valor)}
  end

  def call(otra_lista)
    unless otra_lista.is_a?(Array)
      return false
    end
    if @condicion
      @matchers.size == otra_lista.size ? comparar_listas(@matchers.zip(otra_lista)) : false
    else
      comparar_listas(@matchers.zip(otra_lista))
    end
  end

  def bindear(un_objeto, diccionario)
    if call(un_objeto)
      @matchers.zip(un_objeto).each {|match_list, elem_list| match_list.bindear(elem_list, diccionario)}
    end
  end
end

class PatternMatchingContext
  def initialize(un_objeto)
    @objeto_matcheable = un_objeto
    @lista_pattern = []
  end

  def with(*matchers, &bloque)
    @lista_pattern << With.new(@objeto_matcheable, matchers, &bloque)
  end

  def otherwise(&bloque)
    @lista_pattern << Otherwise.new(&bloque)
  end

  def matchear
    patron_cumple = @lista_pattern.detect {|patron| patron.match}
    patron_cumple.nil? ? (raise MatchError) : patron_cumple.call
  end
end

class With
  def initialize(objeto_matcheable, matchers, &bloque)
    @objeto_matcheable = objeto_matcheable
    @matchers = matchers
    @bloque = bloque
    @diccionario = {}
  end

  def call
    bindear
    self.instance_eval &@bloque
  end

  def bindear
    @matchers.each {|matcher| matcher.bindear(@objeto_matcheable, @diccionario)}
  end

  def match
    @matchers.all? {|un_matcher| un_matcher.call(@objeto_matcheable)}
  end

  def method_missing(sym, *args)
    super unless @diccionario.has_key? sym
    @diccionario[sym]
  end
end

class Otherwise
  def initialize(&bloque)
    @bloque = bloque
  end

  def call
    self.instance_eval &@bloque
  end

  def match
    true
  end
end

class MatchError < StandardError
end