/// Fixtures OSM sintéticas e pequenas para os testes do F.O.G.O. 3D
/// Engine. Cobrem: rua reta, rua curva, cruzamento com nó compartilhado,
/// viaduto SEM nó compartilhado, túnel, edifício com contorno fechado,
/// área com buraco (relation multipolygon), travessia de pedestres,
/// semáforo, tags ausentes e referências inválidas.
library;

import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:fogo/engine/fogo_engine.dart';

const String kFixtureOsm = '''
<?xml version='1.0' encoding='UTF-8'?>
<osm version="0.6" generator="fogo-test">
  <!-- Rua reta: way 10, nós 1..4, largura conhecida (tag width). -->
  <node id="1" lat="-22.2200" lon="-49.9500"/>
  <node id="2" lat="-22.2200" lon="-49.9450">
    <tag k="highway" v="crossing"/>
  </node>
  <node id="3" lat="-22.2200" lon="-49.9400"/>
  <node id="4" lat="-22.2200" lon="-49.9350"/>
  <!-- Rua curva: way 11, nós 5..8. -->
  <node id="5" lat="-22.2250" lon="-49.9500"/>
  <node id="6" lat="-22.2262" lon="-49.9466"/>
  <node id="7" lat="-22.2280" lon="-49.9440"/>
  <node id="8" lat="-22.2305" lon="-49.9420"/>
  <!-- Transversal que cruza a way 10 no nó 2 (junção real). -->
  <node id="9" lat="-22.2150" lon="-49.9450"/>
  <node id="26" lat="-22.2160" lon="-49.9450">
    <tag k="highway" v="traffic_signals"/>
  </node>
  <!-- Viaduto (way 13): cruza a way 10 GEOMETRICAMENTE, sem nó compartilhado. -->
  <node id="10" lat="-22.2190" lon="-49.9470"/>
  <node id="11" lat="-22.2210" lon="-49.9470"/>
  <!-- Túnel (way 14): layer -1. -->
  <node id="12" lat="-22.2350" lon="-49.9500"/>
  <node id="13" lat="-22.2350" lon="-49.9450"/>
  <!-- Edifício com altura conhecida: way 20, anel fechado 21..24..21. -->
  <node id="21" lat="-22.2220" lon="-49.9480"/>
  <node id="22" lat="-22.2220" lon="-49.9470"/>
  <node id="23" lat="-22.2230" lon="-49.9470"/>
  <node id="24" lat="-22.2230" lon="-49.9480"/>
  <!-- Edifício com levels (altura estimada): way 22, anel 43..45..43. -->
  <node id="43" lat="-22.2240" lon="-49.9420"/>
  <node id="44" lat="-22.2240" lon="-49.9410"/>
  <node id="45" lat="-22.2250" lon="-49.9410"/>
  <!-- Área com buraco: relation 30 = outer 31 + inner 36. -->
  <node id="32" lat="-22.2100" lon="-49.9400"/>
  <node id="33" lat="-22.2100" lon="-49.9300"/>
  <node id="34" lat="-22.2200" lon="-49.9300"/>
  <node id="35" lat="-22.2200" lon="-49.9400"/>
  <node id="37" lat="-22.2140" lon="-49.9360"/>
  <node id="38" lat="-22.2140" lon="-49.9340"/>
  <node id="39" lat="-22.2160" lon="-49.9340"/>
  <node id="40" lat="-22.2160" lon="-49.9360"/>
  <!-- Nó inválido: id negativo. -->
  <node id="-1" lat="0" lon="0"/>

  <way id="10">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Rua Reta"/>
    <tag k="width" v="7"/>
  </way>
  <way id="11">
    <nd ref="5"/><nd ref="6"/><nd ref="7"/><nd ref="8"/>
    <tag k="highway" v="secondary"/>
    <tag k="name" v="Rua Curva"/>
  </way>
  <way id="12">
    <nd ref="2"/><nd ref="26"/><nd ref="9"/>
    <tag k="highway" v="primary"/>
    <tag k="lanes" v="2"/>
    <tag k="oneway" v="yes"/>
  </way>
  <way id="13">
    <nd ref="10"/><nd ref="11"/>
    <tag k="highway" v="primary"/>
    <tag k="bridge" v="yes"/>
    <tag k="layer" v="1"/>
  </way>
  <way id="14">
    <nd ref="12"/><nd ref="13"/>
    <tag k="highway" v="residential"/>
    <tag k="tunnel" v="yes"/>
    <tag k="layer" v="-1"/>
  </way>
  <!-- Ref pendente: nó 999 não existe. -->
  <way id="15">
    <nd ref="1"/><nd ref="999"/>
    <tag k="highway" v="track"/>
  </way>
  <!-- Way sem tags: não vira entidade. -->
  <way id="16"><nd ref="1"/><nd ref="4"/></way>
  <way id="20">
    <nd ref="21"/><nd ref="22"/><nd ref="23"/><nd ref="24"/><nd ref="21"/>
    <tag k="building" v="yes"/>
    <tag k="height" v="12.5"/>
  </way>
  <way id="22">
    <nd ref="43"/><nd ref="44"/><nd ref="45"/><nd ref="43"/>
    <tag k="building" v="yes"/>
    <tag k="building:levels" v="3"/>
  </way>
  <way id="31">
    <nd ref="32"/><nd ref="33"/><nd ref="34"/><nd ref="35"/><nd ref="32"/>
  </way>
  <way id="36">
    <nd ref="37"/><nd ref="38"/><nd ref="39"/><nd ref="40"/><nd ref="37"/>
  </way>
  <relation id="30">
    <member type="way" ref="31" role="outer"/>
    <member type="way" ref="36" role="inner"/>
    <tag k="type" v="multipolygon"/>
    <tag k="landuse" v="forest"/>
    <tag k="name" v="Bosque"/>
  </relation>
</osm>
''';

Uint8List fixtureBytes() => Uint8List.fromList(utf8.encode(kFixtureOsm));

/// Mesma fixture comprimida com gzip (formato .osm.gz suportado).
Uint8List fixtureGzipBytes() =>
    Uint8List.fromList(gzip.encode(utf8.encode(kFixtureOsm)));

/// Motor construído a partir da fixture (compartilhado por testes de
/// apresentação/estado que precisam consultar entidades).
final fogoEngineOfTest = FogoEngine.build(fixtureBytes());
