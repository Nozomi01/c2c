import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Color, Icons;

/// **SF Symbols–style icons** for the whole app: all glyphs use [CupertinoIcons]
/// (Apple’s SF Symbols–aligned set in Flutter) so iOS and Android share one look.
///
/// **Exception:** OAuth / vendor brand marks ([facebook], [facebook_outlined],
/// [g_mobiledata_rounded], [apple]) use Material [Icons] where Flutter exposes no
/// matching Cupertino glyph.
class AppIcons {
  AppIcons._();

  // --- Bottom navigation (inactive = line, active = filled) ---
  static const navHomeInactive = CupertinoIcons.house;
  static const navHomeActive = CupertinoIcons.house_fill;
  static const navReservationInactive = CupertinoIcons.calendar;
  static const navReservationActive = CupertinoIcons.calendar_circle_fill;
  static const navBoardInactive = CupertinoIcons.square_pencil;
  static const navBoardActive = CupertinoIcons.square_pencil_fill;
  static const navMessageInactive = CupertinoIcons.chat_bubble;
  static const navMessageActive = CupertinoIcons.chat_bubble_fill;
  static const navProfileInactive = CupertinoIcons.person;
  static const navProfileActive = CupertinoIcons.person_fill;

  static const add = CupertinoIcons.add;
  static const home_outlined = CupertinoIcons.home;
  static const home = CupertinoIcons.house_fill;
  static const list_alt_outlined = CupertinoIcons.square_list;
  static const list_alt = CupertinoIcons.square_list_fill;
  static const chat_bubble_outline = CupertinoIcons.chat_bubble;
  static const chat_bubble = CupertinoIcons.chat_bubble_fill;
  static const person_outline = CupertinoIcons.person;
  static const person = CupertinoIcons.person_fill;

  static const chevron_right = CupertinoIcons.chevron_right;
  static const chevron_left = CupertinoIcons.back;
  static const arrow_back = CupertinoIcons.back;
  static const close = CupertinoIcons.xmark;
  static const send = CupertinoIcons.paperplane_fill;
  static const attach_file = CupertinoIcons.paperclip;
  static const photo_outlined = CupertinoIcons.photo;
  static const keyboard_arrow_down_rounded = CupertinoIcons.chevron_down;

  static const search = CupertinoIcons.search;
  static const notifications_outlined = CupertinoIcons.bell;
  static const help_outline = CupertinoIcons.question_circle;
  static const settings = CupertinoIcons.settings;
  static const grid_view_outlined = CupertinoIcons.square_grid_2x2;
  static const account_balance_wallet_outlined = CupertinoIcons.creditcard;
  static const account_balance_wallet = CupertinoIcons.creditcard_fill;
  static const credit_card = CupertinoIcons.creditcard;
  static const mark_email_unread_outlined = CupertinoIcons.mail;
  static const mark_email_read = CupertinoIcons.mail_solid;
  static const mail_outline = CupertinoIcons.mail;
  static const shopping_bag_outlined = CupertinoIcons.bag;
  static const storefront_outlined = CupertinoIcons.shopping_cart;
  static const phone_android_outlined = CupertinoIcons.device_phone_portrait;
  static const logout = CupertinoIcons.square_arrow_right;
  static const assignment_outlined = CupertinoIcons.doc_text;
  static const assignment = CupertinoIcons.doc_text_fill;
  static const inventory_2_outlined = CupertinoIcons.cube_box;
  static const verified_user_outlined = CupertinoIcons.shield;
  static const verified = CupertinoIcons.checkmark_seal_fill;
  static const check_circle_outline = CupertinoIcons.check_mark_circled;
  static const check = CupertinoIcons.check_mark;
  static const done = CupertinoIcons.check_mark;
  static const done_all = CupertinoIcons.checkmark_alt;

  static const favorite = CupertinoIcons.heart_fill;
  static const favorite_border = CupertinoIcons.heart;
  static const star = CupertinoIcons.star_fill;
  static const star_half = CupertinoIcons.star_lefthalf_fill;
  static const star_border = CupertinoIcons.star;

  static const image = CupertinoIcons.photo;
  static const broken_image_outlined = CupertinoIcons.photo_fill_on_rectangle_fill;
  static const camera_alt = CupertinoIcons.camera;
  static const calendar_today = CupertinoIcons.calendar;
  static const schedule = CupertinoIcons.clock;
  static const access_time = CupertinoIcons.clock;
  static const location_on = CupertinoIcons.location_solid;
  static const share_outlined = CupertinoIcons.share;
  static const edit_note = CupertinoIcons.square_pencil;
  static const sms_outlined = CupertinoIcons.chat_bubble_text;
  static const add_photo_alternate = CupertinoIcons.photo_on_rectangle;
  static const remove_circle_outline = CupertinoIcons.minus_circle;
  static const add_box_outlined = CupertinoIcons.plus_app;
  static const lightbulb_outline = CupertinoIcons.lightbulb;
  static const restaurant_outlined = CupertinoIcons.ellipsis_circle;
  static const sports_esports_outlined = CupertinoIcons.game_controller;

  static const phone_iphone = CupertinoIcons.device_phone_portrait;

  /// Misc UI (search field, menus)
  static const slider_horizontal_3 = CupertinoIcons.slider_horizontal_3;
  static const clear = CupertinoIcons.clear_circled_solid;
  static const forum = CupertinoIcons.text_bubble;
  static const error_outline = CupertinoIcons.exclamationmark_triangle;
  static const place_outlined = CupertinoIcons.location;
  static const more_horiz = CupertinoIcons.ellipsis;

  /// Home category grid
  static const category_talk = CupertinoIcons.chat_bubble_2;
  static const category_advice = CupertinoIcons.lightbulb;
  static const category_cafe = CupertinoIcons.bag;
  static const category_game = CupertinoIcons.game_controller;
  static const category_outing = CupertinoIcons.person_2;
  static const category_other = CupertinoIcons.star;

  /// Home top page (search row, chips, category header, promos)
  static const home_category_header = CupertinoIcons.layers_alt_fill;
  static const home_chip_filter = CupertinoIcons.line_horizontal_3_decrease;
  static const home_promo_gift = CupertinoIcons.gift_fill;
  static const home_promo_bullhorn = CupertinoIcons.speaker_3_fill;
  static const bulletin_section_header = CupertinoIcons.person_3_fill;
  /// Flame used on home horizontal 「人気」section headers (not a category glyph).
  static const home_popular_row_header = CupertinoIcons.flame_fill;

  /// Home category shortcut row — one icon per service type.
  /// [home_row_cafe] / [home_row_meal] use Material [Icons] for clear café / dining glyphs.
  static const home_row_cafe = Icons.local_cafe_rounded;
  static const home_row_consult = CupertinoIcons.bubble_left_bubble_right_fill;
  static const home_row_meal = Icons.restaurant_rounded;
  static const home_row_stroll = CupertinoIcons.map_fill;
  static const home_row_shop = CupertinoIcons.cart_fill;
  static const home_row_hobby_entertainment = CupertinoIcons.sparkles;
  static const home_row_photo_sns = CupertinoIcons.photo_fill_on_rectangle_fill;
  static const home_row_online = CupertinoIcons.globe;

  /// Header for 「注目の新規キャスト」 horizontal row (distinct from category strips).
  static const home_featured_new_cast_row_header = CupertinoIcons.star_circle_fill;

  /// Icons for horizontal recommendation rows keyed by `users.category` (same strings as home shortcuts).
  static IconData homeRecommendedRowIconForCategory(String categoryName) {
    switch (categoryName.trim()) {
      case 'カフェ・お茶':
        return home_row_cafe;
      case '悩み相談':
        return home_row_consult;
      case 'ランチ・食事':
        return home_row_meal;
      case 'お散歩・街歩き':
        return home_row_stroll;
      case 'お買い物':
        return home_row_shop;
      case '趣味・エンタメ':
        return home_row_hobby_entertainment;
      case '写真・SNS':
        return home_row_photo_sns;
      case 'オンライン':
        return home_row_online;
      default:
        return home_popular_row_header;
    }
  }

  /// Tints aligned with the home category shortcut row.
  static Color homeRecommendedRowIconTintForCategory(String categoryName) {
    switch (categoryName.trim()) {
      case 'カフェ・お茶':
        return const Color(0xFFE65100);
      case '悩み相談':
        return const Color(0xFF1565C0);
      case 'ランチ・食事':
        return const Color(0xFFC62828);
      case 'お散歩・街歩き':
        return const Color(0xFF2E7D32);
      case 'お買い物':
        return const Color(0xFF6A1B9A);
      case '趣味・エンタメ':
        return const Color(0xFFD97706);
      case '写真・SNS':
        return const Color(0xFFEC4899);
      case 'オンライン':
        return const Color(0xFF283593);
      default:
        return const Color(0xFFE53935);
    }
  }

  /// OAuth / brand (Material; no SF equivalent in Flutter)
  static const facebook = Icons.facebook;
  static const facebook_outlined = Icons.facebook_outlined;
  static const apple = Icons.apple;
  static const g_mobiledata_rounded = Icons.g_mobiledata_rounded;

  static const alternate_email_outlined = CupertinoIcons.at;
  static const link = CupertinoIcons.link;

  /// Profile / discovery (view counts, etc.)
  static const eye = CupertinoIcons.eye_fill;
}
