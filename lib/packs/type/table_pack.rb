class Wagn::Renderer::Html

  define_view :core, :type=>'table' do |args|
    %{<table id="#{card.name}">
      <thead><tr>
        #{card.table_headers.map do |colhead|
             "<th>#{colhead}</th>"
        end * "\n"}
      </tr></thead>
      <tbody>
      #{card.table_rows.map do |table_row|
         %{<tr> #{ table_row * "\n" } </tr>}
        end * "\n" }
      </tbody></table>
    }
  end
end
