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
    <tag k="crossing" v="marked"/>
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
  <!-- Rotatória: anel fechado (way 40, nós 50..53) + acesso (way 41) no nó 51. -->
  <node id="50" lat="-22.2270" lon="-49.9400"/>
  <node id="51" lat="-22.2270" lon="-49.9380"/>
  <node id="52" lat="-22.2258" lon="-49.9380"/>
  <node id="53" lat="-22.2258" lon="-49.9400"/>
  <node id="54" lat="-22.2270" lon="-49.9430"/>
  <!-- Nó duplicado: id 60 tem EXATAMENTE as coordenadas do nó 4. -->
  <node id="60" lat="-22.2200" lon="-49.9350"/>
  <!-- Paralela muito próxima: way 44 a ~1,5 m da way/10 (mesma rua). -->
  <node id="61" lat="-22.21998" lon="-49.9500"/>
  <node id="62" lat="-22.21998" lon="-49.9450"/>
  <node id="63" lat="-22.21998" lon="-49.9400"/>
  <node id="64" lat="-22.21998" lon="-49.9350"/>
  <!-- Cruzamento em projeção SEM nó compartilhado (way 45 atravessa a
       way/10 exatamente no ponto do nó 2, mas usa nós próprios). -->
  <node id="65" lat="-22.2170" lon="-49.9430"/>
  <node id="66" lat="-22.2230" lon="-49.9430"/>
  <!-- Via terminando no nó DUPLICADO (60 ≈ 4 em coordenadas). -->
  <node id="67" lat="-22.2230" lon="-49.9350"/>

  <way id="40">
    <nd ref="50"/><nd ref="51"/><nd ref="52"/><nd ref="53"/><nd ref="50"/>
    <tag k="highway" v="secondary"/>
    <tag k="junction" v="roundabout"/>
    <tag k="oneway" v="yes"/>
    <tag k="name" v="Rotatória do Centro"/>
  </way>
  <way id="41">
    <nd ref="51"/><nd ref="54"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Acesso da Rotatória"/>
  </way>
  <!-- DUPLICATA COMPROVADA: mesmos nós da way/10 (ATUAL), mesmas tags. -->
  <way id="42">
    <nd ref="1"/><nd ref="99"/><nd ref="2"/><nd ref="3"/><nd ref="101"/>
    <nd ref="4"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Rua Reta"/>
    <tag k="width" v="7"/>
  </way>
  <!-- COINCIDENTE AMBÍGUA: mesmos nós da way/11 (ATUAL), semântica
       diferente. -->
  <way id="43">
    <nd ref="5"/><nd ref="6"/><nd ref="7"/><nd ref="8"/><nd ref="109"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Rua Curva"/>
  </way>
  <!-- PARALELA PRÓXIMA: via legítima, NÃO pode ser deduplicada. -->
  <way id="44">
    <nd ref="61"/><nd ref="62"/><nd ref="63"/><nd ref="64"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Rua Reta"/>
  </way>
  <!-- Cruzando em projeção SEM nó compartilhado: atravessa a way/10 no
       ponto do nó 2 usando nós próprios (65/66) — o motor NÃO conecta. -->
  <way id="45">
    <nd ref="65"/><nd ref="66"/>
    <tag k="highway" v="service"/>
  </way>
  <!-- Termina no nó duplicado 60 (mesma coordenada do nó 4 da way/10):
       sem nó compartilhado → sem conexão topológica. -->
  <way id="46">
    <nd ref="60"/><nd ref="67"/>
    <tag k="highway" v="service"/>
  </way>
  <!-- ETAPA 04: calçada EXPLÍCITA paralela à Rua Reta (nós próprios). -->
  <node id="80" lat="-22.22005" lon="-49.9500"/>
  <node id="81" lat="-22.22005" lon="-49.9450"/>
  <node id="82" lat="-22.22005" lon="-49.9400"/>
  <node id="83" lat="-22.22005" lon="-49.9350"/>
  <way id="55">
    <nd ref="80"/><nd ref="81"/><nd ref="82"/><nd ref="83"/>
    <tag k="highway" v="footway"/>
    <tag k="footway" v="sidewalk"/>
  </way>
  <!-- ETAPA 04: rodovia com PISTAS SEPARADAS (dual carriageway —
       nunca fundidas: ids e nós próprios, mesma rodovia). -->
  <node id="84" lat="-22.2300" lon="-49.9470"/>
  <node id="85" lat="-22.2350" lon="-49.9470"/>
  <node id="86" lat="-22.2300" lon="-49.9474"/>
  <node id="87" lat="-22.2350" lon="-49.9474"/>
  <way id="56">
    <nd ref="84"/><nd ref="85"/>
    <tag k="highway" v="motorway"/>
    <tag k="name" v="Rodovia Dupla"/>
  </way>
  <way id="57">
    <nd ref="86"/><nd ref="87"/>
    <tag k="highway" v="motorway"/>
    <tag k="name" v="Rodovia Dupla"/>
  </way>
  <!-- ETAPA 04: RAMPA (motorway_link) saindo da pista leste (nó 84
       compartilhado) com layer=1 — conecta só ao nível certo. -->
  <node id="88" lat="-22.2300" lon="-49.9430"/>
  <way id="58">
    <nd ref="84"/><nd ref="88"/>
    <tag k="highway" v="motorway_link"/>
    <tag k="layer" v="1"/>
  </way>
  <!-- ETAPA 04: ILHA de tráfego explícita (area:highway, polígono). -->
  <node id="90" lat="-22.2205" lon="-49.9440"/>
  <node id="91" lat="-22.2205" lon="-49.9430"/>
  <node id="92" lat="-22.2203" lon="-49.9430"/>
  <node id="93" lat="-22.2203" lon="-49.9440"/>
  <way id="59">
    <nd ref="90"/><nd ref="91"/><nd ref="92"/><nd ref="93"/><nd ref="90"/>
    <tag k="area:highway" v="traffic_island"/>
  </way>
  <!-- ETAPA 04: estacionamento adjacente à Rua Reta. -->
  <node id="94" lat="-22.2185" lon="-49.9500"/>
  <node id="95" lat="-22.2185" lon="-49.9460"/>
  <node id="96" lat="-22.2175" lon="-49.9460"/>
  <node id="97" lat="-22.2175" lon="-49.9500"/>
  <way id="60">
    <nd ref="94"/><nd ref="95"/><nd ref="96"/><nd ref="97"/><nd ref="94"/>
    <tag k="amenity" v="parking"/>
  </way>

  <way id="10">
    <nd ref="1"/><nd ref="99"/><nd ref="2"/><nd ref="3"/><nd ref="101"/>
    <nd ref="4"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Rua Reta"/>
    <tag k="width" v="7"/>
  </way>
  <way id="11">
    <nd ref="5"/><nd ref="6"/><nd ref="7"/><nd ref="8"/><nd ref="109"/>
    <tag k="highway" v="secondary"/>
    <tag k="name" v="Rua Curva"/>
  </way>
  <way id="12">
    <nd ref="2"/><nd ref="26"/><nd ref="100"/><nd ref="9"/>
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
  <!-- Edifício multipartes: DOIS anéis externos (blocos separados). -->
  <node id="70" lat="-22.2135" lon="-49.9340"/>
  <node id="71" lat="-22.2135" lon="-49.9320"/>
  <node id="72" lat="-22.2125" lon="-49.9320"/>
  <node id="73" lat="-22.2125" lon="-49.9340"/>
  <node id="74" lat="-22.2115" lon="-49.9340"/>
  <node id="75" lat="-22.2115" lon="-49.9320"/>
  <node id="76" lat="-22.2105" lon="-49.9320"/>
  <node id="77" lat="-22.2105" lon="-49.9340"/>
  <way id="48">
    <nd ref="70"/><nd ref="71"/><nd ref="72"/><nd ref="73"/><nd ref="70"/>
    <tag k="building:part" v="no"/>
  </way>
  <way id="49">
    <nd ref="74"/><nd ref="75"/><nd ref="76"/><nd ref="77"/><nd ref="74"/>
  </way>
  <!-- ETAPA 05: travessia SEM marcação explícita (pavimento simples). -->
  <node id="98" lat="-22.2200" lon="-49.9390">
    <tag k="highway" v="crossing"/>
  </node>
  <!-- ETAPA 05: linha de parada (stop) num nó da Reta. -->
  <node id="99" lat="-22.2200" lon="-49.9480">
    <tag k="highway" v="stop"/>
  </node>
  <!-- ETAPA 05: lombada (traffic_calming) na transversal. -->
  <node id="100" lat="-22.2160" lon="-49.9450">
    <tag k="traffic_calming" v="hump"/>
  </node>
  <!-- ETAPA 05: ferrovia ATIVA cruzando a Rua Reta em cruzamento de
       nível real (nó compartilhado 101 = level_crossing). -->
  <node id="101" lat="-22.2200" lon="-49.9470">
    <tag k="railway" v="level_crossing"/>
  </node>
  <node id="102" lat="-22.2150" lon="-49.9470"/>
  <node id="103" lat="-22.2250" lon="-49.9470"/>
  <way id="61">
    <nd ref="102"/><nd ref="101"/><nd ref="103"/>
    <tag k="railway" v="rail"/>
    <tag k="name" v="Ramal Férreo"/>
  </way>
  <!-- ETAPA 05: trilho paralelo independente (mesma linha, eixos
       distintos — nunca fundidos). -->
  <node id="104" lat="-22.2150" lon="-49.9474"/>
  <node id="105" lat="-22.2250" lon="-49.9474"/>
  <way id="62">
    <nd ref="104"/><nd ref="105"/>
    <tag k="railway" v="rail"/>
    <tag k="name" v="Ramal Férreo"/>
  </way>
  <!-- ETAPA 05: trilho CURVO. -->
  <node id="106" lat="-22.2260" lon="-49.9600"/>
  <node id="107" lat="-22.2262" lon="-49.9550"/>
  <node id="108" lat="-22.2268" lon="-49.9510"/>
  <way id="63">
    <nd ref="106"/><nd ref="107"/><nd ref="108"/>
    <tag k="railway" v="rail"/>
  </way>
  <!-- ETAPA 05: travessia em via CURVA (way 11) — obrigatória §7. -->
  <node id="109" lat="-22.2330" lon="-49.9410">
    <tag k="highway" v="crossing"/>
    <tag k="crossing" v="marked"/>
  </node>
  <!-- ETAPA 06: parque côncavo em L (praça com faixa verde). -->
  <node id="120" lat="-22.2090" lon="-49.9490"/>
  <node id="121" lat="-22.2090" lon="-49.9420"/>
  <node id="122" lat="-22.2070" lon="-49.9420"/>
  <node id="123" lat="-22.2070" lon="-49.9450"/>
  <node id="124" lat="-22.2060" lon="-49.9450"/>
  <node id="125" lat="-22.2060" lon="-49.9490"/>
  <way id="70">
    <nd ref="120"/><nd ref="121"/><nd ref="122"/><nd ref="123"/>
    <nd ref="124"/><nd ref="125"/><nd ref="120"/>
    <tag k="leisure" v="park"/>
    <tag k="name" v="Parque Côncavo"/>
  </way>
  <!-- ETAPA 06: rio (waterway=stream) cruzando a região, sob a ponte
       way/13. -->
  <node id="130" lat="-22.2180" lon="-49.9600"/>
  <node id="131" lat="-22.2180" lon="-49.9470"/>
  <node id="132" lat="-22.2180" lon="-49.9350"/>
  <way id="71">
    <nd ref="130"/><nd ref="131"/><nd ref="132"/>
    <tag k="waterway" v="stream"/>
    <tag k="name" v="Córrego"/>
  </way>
  <!-- ETAPA 06: árvores individuais mapeadas (natural=tree). -->
  <node id="140" lat="-22.2085" lon="-49.9485">
    <tag k="natural" v="tree"/>
  </node>
  <node id="141" lat="-22.2080" lon="-49.9470">
    <tag k="natural" v="tree"/>
    <tag k="leaf_type" v="broadleaved"/>
  </node>
  <!-- ETAPA 06: banco (amenity=bench) na beira do parque. -->
  <node id="142" lat="-22.2092" lon="-49.9470">
    <tag k="amenity" v="bench"/>
  </node>
  <relation id="47">
    <member type="way" ref="48" role="outer"/>
    <member type="way" ref="49" role="outer"/>
    <tag k="type" v="multipolygon"/>
    <tag k="building" v="yes"/>
    <tag k="name" v="Complexo Dois Blocos"/>
  </relation>
  <!-- ENG: ESTÁDIO (leisure=stadium) + pitch interno separado — a
       plataforma do lote NUNCA pode cobrir o gramado (elevação do
       pitch acima da plataforma). Nós próprios, sem junções. -->
  <node id="150" lat="-22.2270" lon="-49.9310"/>
  <node id="151" lat="-22.2270" lon="-49.9290"/>
  <node id="152" lat="-22.2286" lon="-49.9286"/>
  <node id="153" lat="-22.2300" lon="-49.9290"/>
  <node id="154" lat="-22.2304" lon="-49.9300"/>
  <node id="155" lat="-22.2300" lon="-49.9310"/>
  <node id="156" lat="-22.2286" lon="-49.9314"/>
  <way id="80">
    <nd ref="150"/><nd ref="151"/><nd ref="152"/><nd ref="153"/>
    <nd ref="154"/><nd ref="155"/><nd ref="156"/><nd ref="150"/>
    <tag k="leisure" v="stadium"/>
    <tag k="sport" v="soccer"/>
    <tag k="name" v="Estádio Fixture"/>
  </way>
  <node id="160" lat="-22.2276" lon="-49.9301"/>
  <node id="161" lat="-22.2276" lon="-49.9299"/>
  <node id="162" lat="-22.2296" lon="-49.9299"/>
  <node id="163" lat="-22.2296" lon="-49.9301"/>
  <way id="81">
    <nd ref="160"/><nd ref="161"/><nd ref="162"/><nd ref="163"/><nd ref="160"/>
    <tag k="leisure" v="pitch"/>
    <tag k="sport" v="soccer"/>
  </way>
</osm>
''';

Uint8List fixtureBytes() => Uint8List.fromList(utf8.encode(kFixtureOsm));

/// Mesma fixture comprimida com gzip (formato .osm.gz suportado).
Uint8List fixtureGzipBytes() =>
    Uint8List.fromList(gzip.encode(utf8.encode(kFixtureOsm)));

/// Motor construído a partir da fixture (compartilhado por testes de
/// apresentação/estado que precisam consultar entidades).
final fogoEngineOfTest = FogoEngine.build(fixtureBytes());
