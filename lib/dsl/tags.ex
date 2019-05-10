defmodule Dsl.Tags do
  alias Phoenix.HTML
  alias Dsl.Utils

  @nonvoid_elements ~w[
    html
    head title style script
    noscript template
    body section nav article aside h1 h2 h3 h4 h5 h6
    header footer address main
    p pre blockquote ol ul li dl dt dd figure figcaption div
    a em strong small s cite q dfn abbr data time code var samp kbd
    sub sup i b u mark ruby rt rp bdi bdo span
    ins del
    iframe object video audio canvas
    map 
    table caption colgroup tbody thead tfoot tr td th
    form fieldset legend label button select datalist optgroup
    option textarea output progress meter
    details summary menuitem menu
  ]a

  @void_elements ~w[
    meta link base
    area br col embed hr img input keygen param source track wbr
  ]a

  @doc false
  def nonvoid_elements, do: @nonvoid_elements
  @doc false
  def void_elements, do: @void_elements

  @doc """
  Creates a markup context.

  All tags must be called inside of a `Dsl.Tags.htm/1` block.

  Returns a safe result of the form `{:safe, result}`

  ## Example

  ```
  team = ["Alice", "Bob", "Carol"]

  htm do
    for name <- team do
      div class: "text-bold" do
        text name
      end
    end
  end

  # {:safe, "<div class=\"text-bold\">Alice</div><div class=\"text-bold\">Bob</div><div class=\"text-bold\">Carol</div>"}
  ```
  """
  defmacro htm([do: block] = _block) do
    quote do
      import Kernel, except: [div: 2]
      import HTML.Link, except: [link: 1, link: 2]
      import HTML.Form, only: []

      {:ok, var!(buff, Dsl.Tags)} = Utils.start_buffer([])

      unquote(block)

      markup = Utils.get_buffer(var!(buff, Dsl.Tags))

      :ok = Utils.stop_buffer(var!(buff, Dsl.Tags))

      markup |> Enum.reverse() |> Enum.join("") |> HTML.raw()
    end
  end

  for el <- @nonvoid_elements do
    @doc """
    #{File.read!("./tmp/docs/#{el}.txt")}
    """
    defmacro unquote(el)() do
      el = unquote(el)

      quote do
        Utils.put_open_tag(var!(buff, Dsl.Tags), unquote(el), [])
        Utils.put_close_tag(var!(buff, Dsl.Tags), unquote(el))
      end
    end

    @doc false
    defmacro unquote(el)([{:do, inner}] = _attrs_or_content_or_block) do
      el = unquote(el)

      quote do
        Utils.put_open_tag(var!(buff, Dsl.Tags), unquote(el), [])
        _ = unquote(inner)
        Utils.put_close_tag(var!(buff, Dsl.Tags), unquote(el))
      end
    end

    defmacro unquote(el)(attrs_or_content_or_block) do
      el = unquote(el)

      quote do
        Utils.put_open_tag(var!(buff, Dsl.Tags), unquote(el), unquote(attrs_or_content_or_block))
        Utils.put_close_tag(var!(buff, Dsl.Tags), unquote(el))
      end
    end

    @doc false
    defmacro unquote(el)(attrs, [{:do, inner}] = _block) do
      el = unquote(el)

      quote do
        attrs = unquote(attrs)
        Utils.put_open_tag(var!(buff, Dsl.Tags), unquote(el), attrs)
        _ = unquote(inner)
        Utils.put_close_tag(var!(buff, Dsl.Tags), unquote(el))
      end
    end

    defmacro unquote(el)(content, attrs) do
      el = unquote(el)

      quote do
        attrs = unquote(attrs)
        Utils.put_open_tag(var!(buff, Dsl.Tags), unquote(el), attrs)
        text unquote(content)
        Utils.put_close_tag(var!(buff, Dsl.Tags), unquote(el))
      end
    end
  end

  for el <- @void_elements do
    @doc """
    #{File.read!("./tmp/docs/#{el}.txt")}
    """

    defmacro unquote(el)(attrs \\ []) do
      el = unquote(el)

      quote do
        attrs = unquote(attrs)

        Utils.put_buffer(
          var!(buff, Dsl.Tags),
          "<#{unquote(el)}#{Utils.compile_attrs(attrs)}>"
        )
      end
    end
  end

  @doc """
  Emits a text node into the markup.

  ```
  htm do
    div do
      text "Hello, world!"
    end
  end

  # {:safe, "<div>Hello, world!</div>"}
  ```
  """
  defmacro text(text) do
    quote do
      Utils.put_buffer(
        var!(buff, Dsl.Tags),
        unquote(text) |> to_string |> HTML.html_escape() |> HTML.safe_to_string()
      )
    end
  end

  @doc """
  Emits a Phoenix partial into the markup

  ```
  htm do
    html lang: "en" do
      head do
        title "MyApp"

        link rel: "stylesheet", href: Routes.static_path(@conn, "/css/app.css")
      end

      body do
        main role: "main", class: "container" do
          p get_flash(@conn, :info), class: "alert alert-info", role: "alert"
          p get_flash(@conn, :error), class: "alert alert-danger", role: "alert"

          partial render(@view_module, @view_template, assigns)
        end

        script type: "text/javascript", src: Routes.static_path(@conn, "/js/app.js")
      end
    end
  end
  ```
  """
  defmacro partial(partial) do
    quote do
      Utils.put_buffer(
        var!(buff, Dsl.Tags),
        unquote(partial) |> Utils.from_safe()
      )
    end
  end

  @doc """
  Defines a custom component.

  ```
  defcomponent :flex do
    div id: @id, class: "flex" do
      @children
    end
  end

  htm do
    flex id: "my-flex" do
      div "Item 1"
      div "Item 2"
      div "Item 3"
    end
  end

  # {:safe, "<div id=\"my-flex\" class=\"flex\">
  #            <div>Item 1</div>
  #            <div>Item 2</div>
  #            <div>Item 3</div>
  #          </div>"}
  ```
  """
  defmacro defcomponent(name, [do: _] = block) do
    quote do
      defmacro unquote(name)(props \\ []) do
        outer = unquote(Macro.escape(block))
        name = unquote(name)

        {inner, props} = Keyword.pop(props, :do, nil)

        quote do
          unquote(name)(unquote(props), unquote(inner))
        end
      end

      defmacro unquote(name)(props, inner) do
        import Kernel, except: [div: 2]

        outer =
          unquote(Macro.escape(block))
          |> Macro.prewalk(&Utils.insert_props(&1, [{:children, inner} | props]))

        name = unquote(name)

        quote do
          unquote(outer)
        end
      end
    end
  end
end