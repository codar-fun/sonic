//// Translation.
////
//// Keys are the English strings themselves, as upstream does — so a view that
//// has not been translated yet still renders correct English rather than a
//// missing-key marker, and adding a language is adding a column here.
////
//// The Chinese was read off the reference site with its `lang` cookie set to
//// `zh`, page by page, rather than machine-translated: these are the words
//// people already see there.

import gleam/list

pub type Lang {
  En
  Zh
}

/// The cookie value, and what the switcher writes.
pub fn code(lang: Lang) -> String {
  case lang {
    En -> "en"
    Zh -> "zh"
  }
}

/// What the header shows for the current language.
pub fn label(lang: Lang) -> String {
  case lang {
    En -> "EN"
    Zh -> "ZH"
  }
}

pub fn parse(value: String) -> Lang {
  case value {
    "zh" -> Zh
    _ -> En
  }
}

/// Translate. English falls through untouched, so an untranslated string is
/// still a correct English one.
pub fn t(lang: Lang, key: String) -> String {
  case lang {
    En -> key
    Zh ->
      case list.key_find(zh, key) {
        Ok(value) -> value
        Error(_) -> key
      }
  }
}

const zh = [
  #("Discover", "发现"),
  #("Sign In", "登录"),
  #("Sign Out", "登出"),
  #("Account", "账户"),
  #("My Events", "我的活动"),
  #("Communities", "社区"),
  #("Events", "活动"),
  #("Groups", "群组"),
  #("Badges", "徽章"),
  #("Want to create your own Group?", "想要创建您自己的社区吗？"),
  #(
    "Start now and let more people freely organize and participate in your exciting events!",
    "立即开始，让更多人自由组织和参与您的精彩活动！",
  ),
  #("Create Now", "现在创建"),
  #("Pop-up Cities", "快闪城市"),
  #("See all Pop-up Cities events", "查看所有快闪城市"),
  #("All", "全部"),
  #("Ongoing", "进行中"),
  #("Upcoming", "即将到来"),
  #("Past", "已结束"),
  #("Host", "主持人"),
  #("Co-Host", "共同发起"),
  #("View map", "查看地图"),
  #("Copy Address", "复制地址"),
  #("Content", "内容"),
  #("Participants", "参与者"),
  #("Attending", "已参加"),
  #("Hosting", "我发起的"),
  #("Co-hosting", "共同主持"),
  #("Starred", "已关注"),
  #("Go", "继续"),
  #("Check your email", "查看您的邮箱"),
  #("Use a different email", "使用其他邮箱"),
  #("Authorized Applications", "已授权应用"),
  #("Developer", "开发者"),
  #("or", "或"),
  #("Google Auth", "Google 登录"),
  #("Ethereum Wallet", "以太坊钱包"),
  #("Sign in to participate in a fun event", "登录以参加有趣的活动"),
  #("Event Schedule", "活动日程"),
  #("Venue List", "场地列表"),
  #("Go to", "前往"),
  #("Filter", "筛选"),
  #("Reset Filter", "重置筛选器"),
  #("Show Events", "显示活动"),
  #("Clear All", "清除全部"),
  #("Cancel", "取消"),
  #("Save", "保存"),
  #("Send", "发送"),
  #("Share", "分享"),
  #("Share Event", "分享活动"),
  #("Copy Link", "复制链接"),
  #("Save Image", "保存图片"),
  #("Event Detail", "活动详情"),
  #("Event Home", "活动主页"),
  #("Create an Event", "创建活动"),
  #("Scan the code", "扫描二维码"),
  #("and attend the event", "参加活动"),
  #("Comments", "评论"),
  #("Edit Profile", "编辑个人资料"),
  #("Nickname", "昵称"),
  #("Bio", "简介"),
  #("Avatar", "头像"),
  #("Social Links", "社交链接"),
  #("Collected", "已收集"),
  #("Created", "已创建"),
  #("Time Range", "时间范围"),
  #("Tags", "标签"),
  #("About us", "关于我们"),
  #("Contact us", "联系我们"),
  #("Feedback", "反馈"),
  #("We value your feedback!", "我们重视您的反馈！"),
  #("Sign in to send a comment", "登录后发表评论"),
  #("Input comment", "输入评论"),
  #("Venues", "场地"),
  #("Capacity", "容量"),
  #("Address", "地址"),
  #("Set a unique group name", "设置一个唯一的群组名称"),
  #("Group name", "群组名称"),
  #("Confirm", "确认"),
  #("Set a unique Social Layer username", "设置一个唯一的 Social Layer 用户名"),
  #("Your username", "你的用户名"),
  #("Underscores can also be used", "也可以使用下划线"),
  #("Create Event", "创建活动"),
  #("Edit Event", "编辑活动"),
  #("Event Name", "活动名称"),
  #("Start Time", "开始时间"),
  #("End Time", "结束时间"),
  #("Timezone", "时区"),
  #("Online Meeting Link", "线上会议链接"),
  #("Description", "描述"),
  #("Group Settings", "群组设置"),
  #("Group Name", "群组名称"),
  #("Location", "地点"),
  #("Add a Venue", "添加场地"),
  #("Venue Name", "场地名称"),
  #("Add a Program", "添加分轨"),
  #("Edit", "编辑"),
  #("Edit Venue", "编辑场地"),
  #("Edit Program", "编辑分轨"),
  #("Program Name", "分轨名称"),
  #("Attend", "参加"),
  #("Cancel Attendance", "取消参加"),
  #(
    "Contain the English-language letters a-z and the digits 0-9",
    "包含英文字母 a-z 和数字 0-9",
  ),
  #(
    "Hyphens can also be used but it can not be used at the beginning and at the end",
    "也可以使用连字符，但不能用在开头和结尾",
  ),
  #("Should be equal or longer than 6 characters", "长度不少于 6 个字符"),
  #("Members", "成员"),
  #("Owner", "所有者"),
  #("Manager", "管理员"),
  #("Member", "成员"),
  #("Make Manager", "设为管理员"),
  #("Remove Manager", "取消管理员"),
  #("Remove", "移除"),
  #("No members yet.", "还没有成员"),
  #("Check In", "签到"),
  #("Send Badge", "发送徽章"),
  #("Receivers", "接收者"),
  #("One username, wallet address or email per line", "每行一个用户名、钱包地址或邮箱"),
  #("Badge sent.", "徽章已发送"),
  #("Bind Email", "绑定邮箱"),
  #("Email", "邮箱"),
  #("Code", "验证码"),
  #("We sent a code to", "我们已发送验证码到"),
  #("Tracks", "分轨"),
  #("Holders", "持有者"),
  #("Search...", "搜索..."),
  #("No events yet.", "暂无活动"),
  #("No events scheduled.", "暂无日程"),
  #("No venues yet.", "暂无场地"),
  #("No one has joined yet.", "还没有人参加"),
]
