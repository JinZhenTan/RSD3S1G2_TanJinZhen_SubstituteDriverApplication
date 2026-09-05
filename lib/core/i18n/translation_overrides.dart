// Hand-picked corrections for UI terms the machine translator gets wrong in
// context - e.g. "Save" comes back as 节省 / "economise" instead of 保存 /
// "store a copy", and "Profile" as 轮廓 / "silhouette" instead of 我的 /
// "my account".
//
// PreferencesProvider.t() checks this map BEFORE the download cache, so an
// entry here always wins (and needs no network call). Keys must match the
// exact English string passed to Tr() / context.tr(); language keys are the
// same codes as TranslationService.languageCodes.
const Map<String, Map<String, String>> translationOverrides = {
  'ms': {
    'Save': 'Simpan',
    'Profile': 'Profil',
    'Home': 'Utama',
    'Activity': 'Aktiviti',
    'Notification': 'Pemberitahuan',
    'Cancel': 'Batal',
    'Add': 'Tambah',
    'Remove': 'Buang',
    'Done': 'Selesai',
    'Default': 'Lalai',
    'Note': 'Nota',
    'Available bookings': 'Tempahan tersedia',
    'Quick actions': 'Tindakan pantas',
    'Sign out': 'Log keluar',
  },
  'zh-CN': {
    'Save': '保存',
    'Profile': '我的',
    'Home': '首页',
    'Activity': '动态',
    'Notification': '通知',
    'Cancel': '取消',
    'Add': '添加',
    'Remove': '移除',
    'Done': '完成',
    'Default': '默认',
    'Note': '备注',
    'Available bookings': '可接订单',
    'Quick actions': '快捷操作',
    'Sign out': '退出登录',
  },
  'ta': {
    'Save': 'சேமி',
    'Profile': 'சுயவிவரம்',
    'Home': 'முகப்பு',
    'Activity': 'செயல்பாடு',
    'Notification': 'அறிவிப்பு',
    'Cancel': 'ரத்துசெய்',
    'Add': 'சேர்',
    'Remove': 'அகற்று',
    'Done': 'முடிந்தது',
    'Default': 'இயல்புநிலை',
    'Note': 'குறிப்பு',
    'Available bookings': 'கிடைக்கும் முன்பதிவுகள்',
    'Quick actions': 'விரைவு செயல்கள்',
    'Sign out': 'வெளியேறு',
  },
};
