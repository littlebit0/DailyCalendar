import 'package:daily/core/academic/kangnam_academic_source.dart';
import 'package:daily/core/academic/expansion_a_academic_sources.dart';
import 'package:daily/core/academic/expansion_b_academic_sources.dart';
import 'package:daily/core/academic/expansion17_c_academic_sources.dart';
import 'package:daily/core/academic/namhae_academic_source.dart';
import 'package:daily/core/academic/geochang_academic_source.dart';
import 'package:daily/core/academic/sch_academic_source.dart';
import 'package:daily/core/academic/hoseo_academic_source.dart';
import 'package:daily/core/academic/kmou_academic_source.dart';
import 'package:daily/core/academic/donga_academic_source.dart';
import 'package:daily/core/academic/konkuk_academic_source.dart';
import 'package:daily/core/academic/jnue_academic_source.dart';
import 'package:daily/core/academic/dgist_academic_source.dart';
import 'package:daily/core/academic/chosun_academic_source.dart';
import 'package:daily/core/academic/gnue_academic_source.dart';
import 'package:daily/core/academic/tuk_academic_source.dart';
import 'package:daily/core/academic/hanyang_academic_source.dart';
import 'package:daily/core/academic/korea_academic_source.dart';
import 'package:daily/core/academic/yonsei_academic_source.dart';
import 'package:daily/core/academic/gachon_academic_source.dart';
import 'package:daily/core/academic/sku_academic_source.dart';
import 'package:daily/core/academic/kyonggi_academic_source.dart';
import 'package:daily/core/academic/cue_academic_source.dart';
import 'package:daily/core/academic/kumoh_academic_source.dart';
import 'package:daily/core/academic/khu_academic_source.dart';
import 'package:daily/core/academic/gknu_academic_source.dart';
import 'package:daily/core/academic/snue_academic_source.dart';
import 'package:daily/core/academic/sungshin_academic_source.dart';
import 'package:daily/core/academic/yu_academic_source.dart';
import 'package:daily/core/academic/mmu_academic_source.dart';
import 'package:daily/core/academic/dnue_academic_source.dart';
import 'package:daily/core/academic/cnu_academic_source.dart';
import 'package:daily/core/academic/hufs_academic_source.dart';
import 'package:daily/core/academic/pnu_academic_source.dart';
import 'package:daily/core/academic/koreatech_academic_source.dart';
import 'package:daily/core/academic/cbnu_academic_source.dart';
import 'package:daily/core/academic/kau_academic_source.dart';
import 'package:daily/core/academic/swu_academic_source.dart';
import 'package:daily/core/academic/hansung_academic_source.dart';
import 'package:daily/core/academic/suwon_academic_source.dart';
import 'package:daily/core/academic/sogang_academic_source.dart';
import 'package:daily/core/academic/mju_academic_source.dart';
import 'package:daily/core/academic/gjue_academic_source.dart';
import 'package:daily/core/academic/cnue_academic_source.dart';
import 'package:daily/core/academic/ginue_academic_source.dart';
import 'package:daily/core/academic/uos_academic_source.dart';
import 'package:daily/core/academic/bu_academic_source.dart';
import 'package:daily/core/academic/cje_academic_source.dart';
import 'package:daily/core/academic/nsu_academic_source.dart';
import 'package:daily/core/academic/kwangwoon_academic_source.dart';
import 'package:daily/core/academic/inha_academic_source.dart';
import 'package:daily/core/academic/inu_academic_source.dart';
import 'package:daily/core/academic/knue_kunsan_academic_source.dart';
import 'package:daily/core/academic/mokpo_academic_source.dart';
import 'package:daily/core/academic/kongju_academic_source.dart';
import 'package:daily/core/academic/hanbat_academic_source.dart';
import 'package:daily/core/academic/hknu_academic_source.dart';
import 'dart:io';
import 'package:daily/core/academic/jbnu_academic_source.dart';
import 'package:daily/core/academic/sv_academic_source.dart';
import 'package:daily/core/academic/dongguk_academic_source.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/snu_academic_source.dart';
import 'package:daily/core/academic/ajou_academic_source.dart';
import 'package:daily/core/academic/gist_academic_source.dart';
import 'package:daily/core/academic/skku_academic_source.dart';
import 'package:daily/core/academic/knu_academic_source.dart';
import 'package:daily/core/academic/daegu_academic_source.dart';
import 'package:daily/core/academic/ulsan_academic_source.dart';
import 'package:daily/core/academic/deu_academic_source.dart';
import 'package:daily/core/academic/bnue_academic_source.dart';
import 'package:daily/core/academic/ut_academic_source.dart';
import 'package:daily/core/academic/kookmin_academic_source.dart';
import 'package:daily/core/academic/unist_academic_source.dart';
import 'package:daily/core/academic/kangwon_academic_source.dart';
import 'package:daily/core/academic/kaist_academic_source.dart';
import 'package:daily/core/academic/cau_academic_source.dart';
import 'package:daily/core/academic/yongin_academic_source.dart';
import 'package:daily/core/academic/jeju_academic_source.dart';
import 'package:daily/core/academic/kmu_academic_source.dart';
import 'package:daily/core/academic/ssu_academic_source.dart';
import 'package:daily/core/academic/syu_academic_source.dart';
import 'package:daily/core/academic/gnu_academic_source.dart';
import 'package:daily/core/academic/pknu_academic_source.dart';
import 'package:daily/core/academic/seoultech_academic_source.dart';

Future<void> main(List<String> args) async {
  final AcademicSource source = switch (args.length > 1 ? args[1] : 'smu') {
    'eulji' => EuljiAcademicSource(),
    'iccu' => IccuAcademicSource(),
    'inje' => InjeAcademicSource(),
    'hongik' => HongikAcademicSource(),
    'wsu' => WoosongAcademicSource(),
    'ewha' => EwhaAcademicSource(),
    'kentech' => KentechAcademicSource(),
    'hansei' => HanseiAcademicSource(),
    'hyupsung' => HyupsungAcademicSource(),
    'sungkyul' => SungkyulAcademicSource(),
    'sunmoon' => SunmoonAcademicSource(),
    'sangji' => SangjiAcademicSource(),
    'nambu' => NambuAcademicSource(),
    'kangnam' => KangnamAcademicSource(),
    'konyang' => KonyangAcademicSource(),
    'dju' => DjuAcademicSource(),
    'pcu' => PcuAcademicSource(),
    'changwon-geochang' => GeochangAcademicSource(),
    'changwon-namhae' => NamhaeAcademicSource(),
    'sch' => SchAcademicSource(),
    'smu' => SangmyungAcademicSource(),
    'dku' => DankookAcademicSource(),
    'jnu' => ChonnamAcademicSource(),
    'snu' => SnuAcademicSource(),
    'postech' => PostechAcademicSource(),
    'sejong' => SejongAcademicSource(),
    'ajou' => AjouAcademicSource(),
    'gist' => GistAcademicSource(),
    'sookmyung' => SookmyungAcademicSource(),
    'skku' => SkkuAcademicSource(),
    'catholic' => CatholicAcademicSource(),
    'knu' => KnuAcademicSource(),
    'daegu' => DaeguAcademicSource(),
    'ulsan' => UlsanAcademicSource(),
    'deu' => DeuAcademicSource(),
    'bnue' => BnueAcademicSource(),
    'ut' => UtAcademicSource(),
    'kookmin' => KookminAcademicSource(),
    'unist' => UnistAcademicSource(),
    'kangwon' => KangwonAcademicSource(),
    'kaist' => KaistAcademicSource(),
    'cau' => CauAcademicSource(),
    'yongin' => YonginAcademicSource(),
    'jeju' => JejuAcademicSource(),
    'kmu' => KmuAcademicSource(),
    'ssu' => SsuAcademicSource(),
    'syu' => SyuAcademicSource(),
    'gnu' => GnuAcademicSource(),
    'inha' => InhaAcademicSource(),
    'inu' => InuAcademicSource(),
    'kwangwoon' => KwangwoonAcademicSource(),
    'nsu' => NsuAcademicSource(),
    'cje' => CjeAcademicSource(),
    'bu' => BuAcademicSource(),
    'uos' => UosAcademicSource(),
    'ginue' => GinueAcademicSource(),
    'cnue' => CnueAcademicSource(),
    'gjue' => GjueAcademicSource(),
    'mju' => MjuAcademicSource(),
    'sogang' => SogangAcademicSource(),
    'swu' => SwuAcademicSource(),
    'koreatech' => KoreatechAcademicSource(),
    'pnu' => PnuAcademicSource(),
    'hufs' => HufsAcademicSource(),
    'cnu' => CnuAcademicSource(),
    'dnue' => DnueAcademicSource(),
    'snue' => SnueAcademicSource(),
    'gknu' => GknuAcademicSource(),
    'khu' => KhuAcademicSource(),
    'kumoh' => KumohAcademicSource(),
    'cue' => CueAcademicSource(),
    'korea' => KoreaAcademicSource(),
    'hanyang' => HanyangAcademicSource(),
    'hanyang-erica' => HanyangAcademicSource(erica: true),
    'tuk' => TukAcademicSource(),
    'gnue' => GnueAcademicSource(),
    'jnue' => JnueAcademicSource(),
    'konkuk' => KonkukAcademicSource(),
    'konkuk-glocal' => KonkukAcademicSource(glocal: true),
    'chosun' => ChosunAcademicSource(),
    'dgist' => DgistAcademicSource(),
    'yonsei' => YonseiAcademicSource(),
    'gachon' => GachonAcademicSource(),
    'sku' => SkuAcademicSource(),
    'kyonggi' => KyonggiAcademicSource(),
    'mmu' => MmuAcademicSource(),
    'yu' => YuAcademicSource(),
    'sungshin' => SungshinAcademicSource(),
    'cbnu' => CbnuAcademicSource(),
    'kau' => KauAcademicSource(),
    'hansung' => HansungAcademicSource(),
    'suwon' => SuwonAcademicSource(),
    'knue' => KnueKunsanAcademicSource.knue(),
    'kunsan' => KnueKunsanAcademicSource.kunsan(),
    'mokpo' => MokpoAcademicSource(),
    'kongju' => KongjuAcademicSource(),
    'hanbat' => HanbatAcademicSource(),
    'hknu' => HknuAcademicSource(),
    'jbnu' => JbnuAcademicSource(),
    'sunchon' => SvAcademicSource.sunchon(),
    'changwon' => SvAcademicSource.changwon(),
    'dongguk-seoul' => DonggukAcademicSource(),
    'dongguk-wise' => DonggukAcademicSource(wise: true),
    'pknu' => PknuAcademicSource(),
    'hoseo' => HoseoAcademicSource(),
    'kmou' => KmouAcademicSource(),
    'donga' => DongaAcademicSource(),
    'seoultech' => SeoultechAcademicSource(),
    _ => throw ArgumentError('Unknown academic source'),
  };
  try {
    final year = args.isEmpty ? DateTime.now().year : int.parse(args.first);
    final events = await source.fetch(year);
    stdout.writeln('${source.name} $year: ${events.length} official events');
    stdout.writeln(
      'Unique IDs: ${events.map((event) => event.dailyId(source.id)).toSet().length}',
    );
    stdout.writeln(
      'All periods valid: ${events.every((event) => event.end.isAfter(event.start))}',
    );
  } finally {
    source.close();
  }
}
