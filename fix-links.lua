-- fix-links.lua — pandoc Lua filter
-- Rewrites .md hrefs to .html so inter-document links work in the HTML output.
-- Handles both  file.md  and  file.md#anchor  forms.
function Link(el)
    el.target = el.target:gsub("%.md$", ".html")
    el.target = el.target:gsub("%.md#", ".html#")
    return el
end
