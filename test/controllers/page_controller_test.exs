defmodule Sketchpad.PageControllerTest do
  use Sketchpad.Web.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Hello Sketchpad!"
  end
end
