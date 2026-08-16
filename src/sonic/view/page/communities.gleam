//// `/communities` — every active group.
////
//// Wrapper classes from seastar-app's `(normal)/communities/page.tsx`; the
//// grid itself is the shared CommunityList so this page and the home page
//// section cannot drift.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/i18n.{type Lang}
import sonic/api/types.{type GroupDetail, type Page}
import sonic/view/community_list

pub fn view(groups: Page(GroupDetail), lang: Lang) -> Element(msg) {
  html.div([attribute.class("page-width min-h-[100svh] pt-0 sm:pt-6 !pb-16")], [
    html.div([attribute.class("text-lg font-semibold my-4")], [
      element.text(i18n.t(lang, "Communities")),
    ]),
    community_list.view(groups.data),
  ])
}
