//Block 1
WITH "https://www.smogon.com/stats/2021-09/chaos/gen8ou-1825.json" AS url
CALL apoc.load.json(url) YIELD value
UNWIND value.data as d
FOREACH (name in keys(d) | CREATE (Pokémon:Pokémon {id: name, teammates: keys(d[name].Teammates)}))
WITH value
UNWIND keys(value.data) as name
MATCH (a:Pokémon) WHERE a.id = name
UNWIND a.teammates as tm
MATCH (b:Pokémon) WHERE b.id = tm
CREATE (a)-[r:Teammate {name: a.id +"<->"+b.id, weight: value.data[a.id].Teammates[b.id]}]->(b)

// Block 2- Preprocessing the data to include only Meta-Relevant Pokemon in Gen 8 OU
MATCH (p:Pokémon)
SET p.teammates = [tm in p.teammates WHERE tm IN ["Barraskewda", "Bisharp", "Blacephalon", "Blissey", "Buzzwole", "Clefable", "Corviknight", "Dragapult", "Dragonite", "Ferrothorn", "Garchomp", "Heatran", "Kartana", "Landorus-Therian", "Magnezone", "Melmetal", "Mew", "Ninetales-Alola", "Pelipper", "Rillaboom", "Slowbro", "Slowking-Galar", "Tapu Fini", "Tapu Koko", "Tapu Lele", "Tornadus-Therian", "Toxapex", "Tyranitar", "Urshifu-Rapid-Strike", "Victini", "Volcanion", "Volcarona", "Weavile", "Zapdos", "Zeraora", "Aegislash", "Amoonguss", "Arctozolt", "Avalugg", "Azumarill", "Blaziken", "Celesteela", "Charizard", "Cloyster", "Conkeldurr", "Crawdaunt", "Cresselia", "Ditto", "Dracozolt", "Excadrill", "Gastrodon", "Gengar", "Glastrier", "Grimmsnarl", "Hatterene", "Hawlucha", "Haxorus", "Hippowdon", "Hydreigon", "Jirachi", "Keldeo", "Kingdra", "Kommo-o", "Latias", "Latios", "Mamoswine", "Mandibuzz", "Marowak-Alola", "Moltres", "Moltres-Galar", "Nidoking", "Nihilego", "Polteageist", "Primarina", "Quagsire", "Regieleki", "Reuniclus", "Rotom-Heat", "Rotom-Wash", "Scizor", "Seismitoad", "Shedinja", "Shuckle", "Skarmory", "Slowking", "Suicune", "Swampert", "Tangrowth", "Tapu Bulu", "Terrakion", "Thundurus-Therian", "Togekiss", "Torkoal", "Toxtricity", "Venusaur", "Xatu", "Zapdos-Galar", "Zarude"]];

//Block 3
With 40 as threshold
MATCH p=()-[r:Teammate]->() WHERE r.weight < threshold DELETE r

// Block 4 
MATCH ()-[r:Teammate]->() WITH toFloat(max(r.weight)) as max
MATCH ()-[r:Teammate]->() SET r.nweight = toFloat(r.weight) / max

// Block 5 
CALL gds.graph.project(
"myGraph1",
"Pokémon",
"Teammate",
{
relationshipProperties: "nweight"
})

// Block 6
MATCH (p:Pokémon)-[r:Teammate]->(m:Pokémon)
RETURN p, r, m

// Block 7
CALL gds.louvain.write('myGraph1', { writeProperty: 'community', relationshipWeightProperty: 'nweight' })YIELD communityCount

// Block 8
MATCH (p:Pokémon)
WITH p, p.community as community, 
     [(p)-[:Teammate]- () | 1] AS relationships
ORDER BY community ASC, size(relationships) DESC
WITH community, (head(collect(p))).id as top, count(*) as size, 
     collect(p.id)[0..6] as likelyTeam, collect(p) as all
ORDER BY size DESC
FOREACH (pokemon IN all | SET pokemon.communityName = top)

// Block 9
MATCH (p:Pokémon)
CALL apoc.create.addLabels(p,[p.communityName]) yield node RETURN node

// Block 10
MATCH (p:Pokémon)
REMOVE p:Pokémon
RETURN p.name, labels(p)

// Block 11
MATCH pkmn=()-[r:Teammate]->() RETURN pkmn

//Block 12- Generating Weighted Random Walks based on the normalized weight property
CALL gds.randomWalk.stream(
  'myGraph1',
  {
    walkLength: 6,
    walksPerNode: 1,
    randomSeed: 42,
    concurrency: 1,
    relationshipWeightProperty: 'nweight'
  }
)
YIELD nodeIds, path
RETURN nodeIds, [nodeId IN nodeIds | gds.util.asNode(nodeId).id] AS pokemonNames, path

//Block 13- Generating Node Embeddings for Nodes using Node2Vec
CALL gds.node2vec.stream('myGraph', {embeddingDimension: 128})
YIELD nodeId, embedding
RETURN nodeId, embedding