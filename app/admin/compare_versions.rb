ActiveAdmin.register_page "Compare Versions" do
  controller do
  end

  menu priority: 3, label: proc { I18n.t("active_admin.compare_versions") }
  #menu false

  limit = 10

  content title: proc { I18n.t("active_admin.compare_versions") } do

    matches, model = diff_find_in_interval(Source, current_user, params[:time_frame], params[:rule])

    if matches.empty?
      text_node "pao pao"
      next
    end

    # Note: we only display one match at a time, as it is always
    # limited to one rule. So the first one is the only result
    match_name, sources = matches.first
    paginated = Kaminari.paginate_array(sources)
    per_page = params.include?(:compare_version_quantity) ? params[:compare_version_quantity] : 20

    paginated_collection(paginated.page(params[:src_list_page]).per(per_page), param_name: "src_list_page", download_links: false) do
      items = collection

      panel "Rule: #{match_name}" do

        table do

          tr do
            th { text_node "id" }
            if model == Source
              th { text_node "composer" }
              th { text_node "title" }
            elsif model == Institution
              th { text_node "name" }
              th { text_node "siglum" }
            elsif model == Work
              th { text_node "composer" }
              th { text_node "title" }
            end
            th { text_node "created at" }
            th { text_node "updated at" }
            th { text_node "similarity" }
            th { text_node "diff" }
          end

          items.each do |s|
            sim = 0

            if !s.versions.empty?
              version = s.versions.last
              s.marc.load_from_array(VersionChecker.get_diff_with_next(version.id))
              sim = VersionChecker.get_similarity_with_next(version.id)
            end

            classes = [helpers.cycle("odd", "even")]
            tr(class: classes.flatten.join(" ")) do
              td { s.id }
              if model == Source
                td { s.composer rescue "" }
                td { s.std_title rescue "" }
              elsif model == Institution
                td { s.name rescue "" }
                td { s.siglum rescue "" }
              elsif model == Work
                td { s.person.name rescue "" }
                td { s.title rescue "" }
              end
              td { s.created_at }
              td { s.updated_at }

              td do
                div(id: "marc_editor_history", class: "modification_bar") do
                  if sim == 0
                    status_tag(:published, label: "New record")
                  else                    
                    div(class: "modification_bar_content version_modification", style: "width: #{sim}%") do
                      "&nbsp".html_safe
                    end
                  end
                end
              end

              td do
                id = s.versions.last != nil ? s.versions.last.id.to_s : "1"
                link_to("show", "#", class: "diff-button", name: "diff-#{s.id}")
              end
            end
            tr do
              td(colspan: 7, class: "diff", id: "diff-#{s.id}", style: "display: none") do
                render(partial: "diff_record", locals: { :item => s })
              end
            end
          end
        end
      end
    end

  end # content

  sidebar I18n.t "dashboard.selection", :class => "sidebar_tabs", :only => [:index] do
    # no idea why the I18n.locale is not set by set_locale in the ApplicationController
    I18n.locale = session[:locale]
    render("compare_sidebar") # Calls a partial
  end
end
