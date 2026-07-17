import Foundation

/// V1 site catalogue — mirrors SITES array from chronicarum.html.
/// Extend with UNESCO JSON feed once backend is wired.
enum SiteData {
    static let all: [Site] = [
        Site(
            id: "colosseum",
            name: "Colosseum",
            location: "Rome, Italy",
            latitude: 41.89,
            longitude: 12.49,
            era: .classical,
            type: .wonder,
            tier: 5,
            builtDescription: "70–80 AD",
            civilisation: "Roman Empire",
            tagline: "Where 65,000 Romans roared as one",
            chapters: [
                Chapter(
                    id: "colosseum-origin",
                    title: "Origin",
                    eyebrow: "The Gift to Rome",
                    heading: "Built on the ruins of Nero's vanity",
                    body: "<p>When Emperor <strong>Vespasian</strong> came to power in 69 AD, Nero's monstrous private lake sat at the heart of Rome — a symbol of imperial excess. Vespasian's masterstroke: drain it, and build the greatest arena the world had ever seen on the same ground. A gift from the Emperor to the people.</p><p>Construction began in <strong>70 AD</strong>. The labour was partly provided by Jewish prisoners captured after the siege of Jerusalem. In just ten years, a structure of 100,000 tonnes of travertine limestone rose four storeys — the largest amphitheatre ever built.</p>",
                    facts: [
                        Fact(label: "Built", value: "70–80 AD"),
                        Fact(label: "Capacity", value: "65,000–80,000 spectators"),
                        Fact(label: "Height", value: "48 metres (4 storeys)"),
                        Fact(label: "Material", value: "100,000 tonnes travertine"),
                    ]
                ),
                Chapter(
                    id: "colosseum-at-its-peak",
                    title: "At Its Peak",
                    eyebrow: "The Spectacle of Power",
                    heading: "A machine of death built with precision engineering",
                    body: "<p>Below the arena floor lay the <strong>hypogeum</strong> — two underground levels of tunnels, cages, and hydraulic lifts that could launch animals directly into the arena through trap doors. Gladiators, lions, bears, and elephants waited in darkness beneath the feet of 65,000 screaming Romans.</p><p>The <strong>velarium</strong> — a vast retractable canvas awning — was rigged by 1,000 sailors from the Roman fleet to shade the crowd. During inaugural games under Titus in 80 AD, <strong>9,000 animals</strong> were slaughtered over 100 days.</p>",
                    facts: [
                        Fact(label: "Duration of Games", value: "100 days at opening"),
                        Fact(label: "Animals Killed", value: "9,000 (inaugural games)"),
                        Fact(label: "Underground Levels", value: "2 (the hypogeum)"),
                        Fact(label: "Shade System", value: "Velarium — rigged by 1,000 sailors"),
                    ]
                ),
                Chapter(
                    id: "colosseum-the-fall",
                    title: "The Fall",
                    eyebrow: "Stripped to the Bones",
                    heading: "Quarried for centuries — saved by a Pope",
                    body: "<p>After Rome's fall, the Colosseum became a quarry. Its marble seating, bronze clamps, and stone were stripped — much of it used in the construction of <strong>St Peter's Basilica</strong> and other Roman churches. An earthquake in 1349 collapsed the south outer wall entirely.</p><p>In <strong>1749</strong>, Pope Benedict XIV finally halted the destruction by declaring the Colosseum sacred ground — consecrated by the blood of Christian martyrs who, according to tradition, had died within its walls.</p>",
                    facts: [
                        Fact(label: "Sacking began", value: "6th century AD"),
                        Fact(label: "Major earthquake", value: "1349 AD"),
                        Fact(label: "Saved by", value: "Pope Benedict XIV, 1749"),
                        Fact(label: "Stone reused in", value: "St Peter's Basilica, Rome"),
                    ]
                ),
                Chapter(
                    id: "colosseum-today",
                    title: "Today",
                    eyebrow: "Living Monument",
                    heading: "The most visited monument on Earth",
                    body: "<p>More than <strong>7 million people</strong> visit the Colosseum each year — more than any other monument in the world. The arena floor, long absent, was partially reconstructed in 2023 and will be fully restored by 2025, allowing visitors to stand where gladiators once stood.</p><p>At night, lit amber against the Roman darkness, it is an overwhelming thing to see. No photograph has ever done it justice. It demands to be stood before in person — which is precisely the point of Chronicarum.</p>",
                    facts: [
                        Fact(label: "Annual visitors", value: "7 million+"),
                        Fact(label: "UNESCO listed", value: "1980"),
                        Fact(label: "Floor restoration", value: "Completed 2024"),
                        Fact(label: "Night lighting", value: "Amber LED since 2015"),
                    ]
                ),
            ],
            nearestAirport: "Rome Fiumicino (FCO)",
            bestTimeToVisit: "April–June or September–October",
            visaNote: "EU/Schengen — 90-day visa-free for most Western passports"
        ),
        Site(
            id: "machu-picchu",
            name: "Machu Picchu",
            location: "Cusco Region, Peru",
            latitude: -13.16,
            longitude: -72.54,
            era: .renaissance,
            type: .wonder,
            tier: 5,
            builtDescription: "c. 1450 AD",
            civilisation: "Inca Empire",
            tagline: "The city the Spanish never found",
            chapters: [
                Chapter(
                    id: "machu-picchu-origin",
                    title: "Origin",
                    eyebrow: "The Emperor's Estate",
                    heading: "Built by a conquering god — then abandoned to the clouds",
                    body: "<p>Around <strong>1450 AD</strong>, the Inca Emperor <strong>Pachacuti</strong> — the man who transformed a small Andean kingdom into the largest empire in the Americas — built Machu Picchu as his personal royal estate. It sat 2,430 metres above sea level, on a saddle between two mountain peaks, above a bend in the Urubamba River.</p><p>Some 200 stone structures were constructed without mortar, with such precision that a sheet of paper still cannot be inserted between the stones. The city aligned with astronomical events — the summer solstice sun rises directly over the Intihuatana stone.</p>",
                    facts: [
                        Fact(label: "Built", value: "c. 1450 AD"),
                        Fact(label: "Elevation", value: "2,430 metres"),
                        Fact(label: "Builder", value: "Emperor Pachacuti"),
                        Fact(label: "Structures", value: "~200 buildings"),
                    ]
                ),
                Chapter(
                    id: "machu-picchu-at-its-peak",
                    title: "At Its Peak",
                    eyebrow: "City in the Sky",
                    heading: "An engineering marvel without mortar, wheel, or iron",
                    body: "<p>At its height, Machu Picchu housed around <strong>750 people</strong> — priests, workers, and selected women who served the Emperor. The Inca had no written language, no iron tools, no wheel. They used bronze chisels, rope, and human labour to move stones weighing up to 25 tonnes up a mountain.</p><p>An <strong>agricultural terrace system</strong> (andenes) cascaded down the mountainside, growing food for the city. Sophisticated drainage channels managed rainfall so effectively that the city has never flooded in nearly 600 years.</p>",
                    facts: [
                        Fact(label: "Population (peak)", value: "~750 residents"),
                        Fact(label: "Heaviest stone", value: "~25 tonnes"),
                        Fact(label: "Terraces", value: "700+ agricultural terraces"),
                        Fact(label: "Technology used", value: "Bronze, rope, human labour"),
                    ]
                ),
                Chapter(
                    id: "machu-picchu-the-abandonment",
                    title: "The Abandonment",
                    eyebrow: "Vanished from History",
                    heading: "Left intact — and completely forgotten for 350 years",
                    body: "<p>When the Spanish conquistadors swept through the Inca Empire after 1532, they never found Machu Picchu. The city was abandoned — possibly due to smallpox, which preceded the Spanish themselves — around <strong>1572</strong>. The jungle swallowed it completely.</p><p>For 350 years it sat in the mountains, known only to a handful of local farmers who quietly cultivated its terraces. No Spanish record mentions it. It was the most perfect secret in the Americas.</p>",
                    facts: [
                        Fact(label: "Abandoned", value: "c. 1572 AD"),
                        Fact(label: "Reason", value: "Likely smallpox epidemic"),
                        Fact(label: "Spanish found it?", value: "No — never discovered"),
                        Fact(label: "Years forgotten", value: "~350 years"),
                    ]
                ),
                Chapter(
                    id: "machu-picchu-rediscovery",
                    title: "Rediscovery",
                    eyebrow: "1911",
                    heading: "A Yale professor, a local boy, and the find of the century",
                    body: "<p>On <strong>24 July 1911</strong>, American explorer <strong>Hiram Bingham III</strong> was guided up the mountain by a local farmer and his 11-year-old son, Pablito Alvarez. Through the overgrowth, stone walls emerged. Bingham reported it as the \"Lost City of the Incas\" — though archaeologists now believe it was never truly lost to those who lived nearby.</p><p>Bingham's photographs, published in <strong>National Geographic</strong> in 1913, showed the world a city that seemed to hover in the clouds. The response was electrifying. Machu Picchu became the image of Inca civilisation forever.</p>",
                    facts: [
                        Fact(label: "Rediscovered", value: "24 July 1911"),
                        Fact(label: "Discoverer", value: "Hiram Bingham III"),
                        Fact(label: "Local guide", value: "Pablito Alvarez (age 11)"),
                        Fact(label: "UNESCO listed", value: "1983"),
                    ]
                ),
            ],
            nearestAirport: "Alejandro Velasco Astete (CUZ)",
            bestTimeToVisit: "May–October (dry season)",
            visaNote: "Visa-free for most passports up to 90 days"
        ),
        Site(
            id: "angkor-wat",
            name: "Angkor Wat",
            location: "Siem Reap, Cambodia",
            latitude: 13.41,
            longitude: 103.87,
            era: .medieval,
            type: .sacred,
            tier: 5,
            builtDescription: "Early 12th century",
            civilisation: "Khmer Empire",
            tagline: "The largest religious structure ever built",
            chapters: [
                Chapter(
                    id: "angkor-wat-origin",
                    title: "Origin",
                    eyebrow: "A Temple to the Universe",
                    heading: "Larger than anything Rome or Egypt ever built",
                    body: "<p><strong>King Suryavarman II</strong> began construction around 1113 AD. He intended Angkor Wat not merely as a temple but as a symbolic representation of <strong>Mount Meru</strong> — the home of the gods in Hindu cosmology. Every measurement was a metaphor. Every corridor told a story in stone.</p><p>The complex covers <strong>400 acres</strong>. Its outer wall alone is 3.6 kilometres long. By comparison, the entire city of Paris within its medieval walls would fit inside. It required an estimated <strong>300,000 workers</strong> and 30 years to complete.</p>",
                    facts: [
                        Fact(label: "Built", value: "1113–1150 AD"),
                        Fact(label: "Area", value: "400 acres (162 hectares)"),
                        Fact(label: "Outer moat", value: "5.6km around, 190m wide"),
                        Fact(label: "Workers", value: "est. 300,000"),
                    ]
                ),
                Chapter(
                    id: "angkor-wat-at-its-peak",
                    title: "At Its Peak",
                    eyebrow: "Capital of a Million People",
                    heading: "The largest pre-industrial city on Earth",
                    body: "<p>Angkor — the capital city surrounding the temple — was home to roughly <strong>one million people</strong> at its height, making it the largest pre-industrial city on Earth. Rome at its peak held perhaps 500,000. The hydraulic network feeding the city — canals, reservoirs, and rice paddies — stretched for thousands of square kilometres.</p><p>Angkor Wat's <strong>bas-reliefs</strong> stretch for 800 metres and are the longest continuous carved narrative in the world, depicting the Hindu epic Mahabharata, historic battles, and the churning of the cosmic ocean.</p>",
                    facts: [
                        Fact(label: "City population", value: "~1 million (at peak)"),
                        Fact(label: "Bas-relief length", value: "800 metres continuous"),
                        Fact(label: "Water network", value: "Thousands of sq km of canals"),
                        Fact(label: "Religion depicted", value: "Hindu (later Buddhist)"),
                    ]
                ),
                Chapter(
                    id: "angkor-wat-the-fall",
                    title: "The Fall",
                    eyebrow: "Swallowed by the Jungle",
                    heading: "Thai invasion ends the empire — the forest takes the rest",
                    body: "<p>The Khmer Empire was weakened by repeated wars with the <strong>Thai Kingdom of Ayutthaya</strong>. In <strong>1431</strong>, Angkor was sacked and its royal court relocated to Phnom Penh. The city was gradually abandoned. Within decades, the jungle began its slow reclamation.</p><p>The temple itself was never fully abandoned — Buddhist monks maintained a presence continuously — but the city around it disappeared entirely. By the time Europeans arrived, trees hundreds of years old had grown through the stones, their roots gripping the walls in an eerie embrace.</p>",
                    facts: [
                        Fact(label: "Sacked", value: "1431 by Ayutthaya Kingdom"),
                        Fact(label: "Capital moved to", value: "Phnom Penh"),
                        Fact(label: "Buddhist monks", value: "Present continuously since medieval era"),
                        Fact(label: "Notable tree", value: "Ta Prohm — famous jungle-swallowed temple"),
                    ]
                ),
                Chapter(
                    id: "angkor-wat-rediscovery",
                    title: "Rediscovery",
                    eyebrow: "1860",
                    heading: "\"Grander than anything left to us by Greece or Rome\"",
                    body: "<p>French explorer <strong>Henri Mouhot</strong> encountered Angkor Wat in 1860 while collecting insects for the British Museum. His description — published posthumously after his death from fever — described it as grander than anything left to us by Greece or Rome. The Western world was electrified.</p><p>Today Angkor Wat appears on the <strong>Cambodian national flag</strong> — the only building in the world so honoured. It receives over 2 million visitors per year, and UNESCO-led restoration work continues to stabilise the ancient stones against the encroaching jungle.</p>",
                    facts: [
                        Fact(label: "Rediscovered (West)", value: "1860 by Henri Mouhot"),
                        Fact(label: "On national flag?", value: "Yes — Cambodia (unique in world)"),
                        Fact(label: "UNESCO listed", value: "1992"),
                        Fact(label: "Annual visitors", value: "2.2 million"),
                    ]
                ),
            ],
            nearestAirport: "Siem Reap International (REP)",
            bestTimeToVisit: "November–March",
            visaNote: "e-Visa available; 30-day single entry"
        ),
        Site(
            id: "petra",
            name: "Petra",
            location: "Ma'an Governorate, Jordan",
            latitude: 30.33,
            longitude: 35.44,
            era: .classical,
            type: .lostCity,
            tier: 5,
            builtDescription: "4th century BC – 2nd century AD",
            civilisation: "Nabataean Kingdom",
            tagline: "The rose-red city lost for a thousand years",
            chapters: [
                Chapter(
                    id: "petra-origin",
                    title: "Origin",
                    eyebrow: "The Nabataeans",
                    heading: "Carved from rose-red sandstone by desert traders",
                    body: "<p>The <strong>Nabataeans</strong> were Arab traders who carved an extraordinary civilisation from the cliff faces of southern Jordan. Beginning around the <strong>4th century BC</strong>, they began cutting the city of Petra directly into the pink and red sandstone — temples, tombs, a theatre, and colonnaded streets, all excavated rather than constructed.</p><p>Their supreme achievement was water. In a desert that receives less than 150mm of rain per year, the Nabataeans engineered an extraordinary system of cisterns, dams, and ceramic pipes that delivered fresh water to 20,000 people. It was the genius of Petra — not the architecture, but the plumbing.</p>",
                    facts: [
                        Fact(label: "Founded", value: "c. 4th century BC"),
                        Fact(label: "People", value: "Nabataean Arabs"),
                        Fact(label: "Carved into", value: "Sandstone cliffs"),
                        Fact(label: "Water system", value: "Ceramic pipes, 200km of channels"),
                    ]
                ),
                Chapter(
                    id: "petra-at-its-peak",
                    title: "At Its Peak",
                    eyebrow: "Crossroads of the World",
                    heading: "Spices, silk, and incense flowed through its gates",
                    body: "<p>Petra sat at the intersection of trade routes connecting <strong>Arabia, Egypt, the Mediterranean, and China</strong>. Incense from Yemen, silk from China, spices from India — all passed through Petra. The Nabataeans taxed every caravan and grew fabulously wealthy.</p><p>At its height, Petra housed perhaps <strong>20,000 people</strong>. The Treasury — the Al-Khazneh — was almost certainly a royal tomb, not a treasury, but its 40-metre carved facade is the most photographed image in the Middle East. The rock face above it still bears the marks of Bedouin rifles, fired for centuries in hope of releasing gold hidden inside.</p>",
                    facts: [
                        Fact(label: "Peak population", value: "~20,000"),
                        Fact(label: "The Treasury height", value: "40 metres"),
                        Fact(label: "Trade goods", value: "Incense, silk, spices, gold"),
                        Fact(label: "The theatre", value: "Seats 8,500 people"),
                    ]
                ),
                Chapter(
                    id: "petra-the-fall",
                    title: "The Fall",
                    eyebrow: "Forgotten for 1,000 Years",
                    heading: "Rome annexed it; an earthquake broke it; the desert buried it",
                    body: "<p>In <strong>106 AD</strong>, the Roman Emperor Trajan absorbed the Nabataean Kingdom as the province of Arabia Petraea. Rome built a colonnaded street through Petra, but trade routes began shifting north. In <strong>363 AD</strong>, a catastrophic earthquake destroyed much of the city. The Byzantine period brought churches and partial recovery, but the city was gradually abandoned.</p><p>By the medieval period, Petra had been entirely forgotten by the outside world. The Bedouin tribes of the region knew it simply as their ancestral home, never thinking to announce it to passing scholars.</p>",
                    facts: [
                        Fact(label: "Roman annexation", value: "106 AD"),
                        Fact(label: "Major earthquake", value: "363 AD"),
                        Fact(label: "Christianity arrived", value: "4th century AD"),
                        Fact(label: "Fully abandoned", value: "by ~8th century AD"),
                    ]
                ),
                Chapter(
                    id: "petra-rediscovery",
                    title: "Rediscovery",
                    eyebrow: "1812",
                    heading: "A Swiss scholar in disguise penetrates the forbidden valley",
                    body: "<p>In <strong>1812</strong>, Swiss explorer <strong>Johann Ludwig Burckhardt</strong> heard rumours of a lost city in the Jordanian desert. To gain access, he disguised himself as a Muslim pilgrim intending to sacrifice a goat at the tomb of the Prophet Aaron. His Bedouin guide led him through the narrow canyon of the <strong>Siq</strong> — and suddenly, through a crack in the cliff, the Treasury appeared.</p><p>Burckhardt wrote a brief description and said nothing more — afraid of betraying his disguise by showing too much excitement. He died of fever in Cairo six years later. His journals, published posthumously, changed the world's understanding of the ancient Near East.</p>",
                    facts: [
                        Fact(label: "Rediscovered", value: "22 August 1812"),
                        Fact(label: "Discoverer", value: "Johann Ludwig Burckhardt"),
                        Fact(label: "His disguise", value: "Muslim pilgrim"),
                        Fact(label: "UNESCO listed", value: "1985"),
                    ]
                ),
            ],
            nearestAirport: "King Hussein International (AQJ)",
            bestTimeToVisit: "March–May or September–November",
            visaNote: "Jordan Pass available; visa on arrival for most"
        ),
        Site(
            id: "acropolis",
            name: "Acropolis of Athens",
            location: "Athens, Greece",
            latitude: 37.97,
            longitude: 23.73,
            era: .classical,
            type: .wonder,
            tier: 5,
            builtDescription: "5th century BC",
            civilisation: "Athenian / Greek",
            tagline: "The rock where democracy was born",
            chapters: [
                Chapter(
                    id: "acropolis-overview",
                    title: "Overview",
                    eyebrow: "The High City",
                    heading: "Built in the golden age — still commanding after 2,500 years",
                    body: "<p>The <strong>Parthenon</strong> was built under the leadership of the statesman Pericles between <strong>447 and 432 BC</strong> — at the height of Athenian democracy. Architects Ictinus and Callicrates and the sculptor Pheidias created a building so optically refined that not a single straight line exists in it. Every column subtly bulges in the middle; every surface is curved — all to correct for optical illusion and make the building appear perfect to the human eye.</p><p>Within it stood a 12-metre gold and ivory statue of <strong>Athena</strong> — lost entirely. The frieze that wrapped its exterior depicted the Panathenaic Procession. Half of what remains sits in the British Museum. The rest sits here, in Athens, waiting.</p>",
                    facts: [
                        Fact(label: "Built", value: "447–432 BC"),
                        Fact(label: "Architects", value: "Ictinus & Callicrates"),
                        Fact(label: "Columns", value: "46 outer, 23 inner"),
                        Fact(label: "Elgin Marbles", value: "50% in British Museum since 1816"),
                    ]
                ),
            ],
            nearestAirport: "Athens International Eleftherios Venizelos (ATH)",
            bestTimeToVisit: "April–June or September–October",
            visaNote: "EU/Schengen"
        ),
        Site(
            id: "pompeii",
            name: "Pompeii",
            location: "Campania, Italy",
            latitude: 40.75,
            longitude: 14.49,
            era: .classical,
            type: .lostCity,
            tier: 5,
            builtDescription: "Founded 7th–6th century BC; destroyed 79 AD",
            civilisation: "Roman Empire",
            tagline: "Frozen in the ash of Vesuvius",
            chapters: [],
            nearestAirport: "Naples International (NAP)",
            bestTimeToVisit: "April–June or September–October",
            visaNote: "EU/Schengen"
        ),
        Site(
            id: "valley-of-kings",
            name: "Valley of the Kings",
            location: "Luxor, Egypt",
            latitude: 25.74,
            longitude: 32.60,
            era: .ancient,
            type: .treasure,
            tier: 5,
            builtDescription: "16th–11th century BC",
            civilisation: "New Kingdom Egypt",
            tagline: "Where pharaohs slept for eternity",
            chapters: [
                Chapter(
                    id: "valley-of-kings-overview",
                    title: "Overview",
                    eyebrow: "The Necropolis of Pharaohs",
                    heading: "63 royal tombs cut into limestone cliffs",
                    body: "<p>For 500 years — from roughly <strong>1539 to 1075 BC</strong> — every pharaoh of Egypt's New Kingdom was buried in the Valley of the Kings on the west bank of the Nile at Luxor. The valley contains <strong>63 known tombs</strong>, ranging from simple pits to elaborately decorated corridors stretching 200 metres into the cliff face.</p><p>Every tomb was robbed in antiquity — except one. On <strong>4 November 1922</strong>, Howard Carter's team discovered the untouched tomb of the boy-king <strong>Tutankhamun</strong>. The treasures inside took ten years to catalogue and redefined the world's understanding of ancient Egyptian wealth.</p>",
                    facts: [
                        Fact(label: "In use", value: "1539–1075 BC (500 years)"),
                        Fact(label: "Known tombs", value: "63"),
                        Fact(label: "Notable tomb", value: "KV62 — Tutankhamun (1922)"),
                        Fact(label: "Objects in KV62", value: "5,398 artefacts"),
                    ]
                ),
            ],
            nearestAirport: "Luxor International (LXR)",
            bestTimeToVisit: "October–April",
            visaNote: "e-Visa available online"
        ),
        Site(
            id: "edinburgh-castle",
            name: "Edinburgh Castle",
            location: "Edinburgh, Scotland",
            latitude: 55.95,
            longitude: -3.20,
            era: .medieval,
            type: .castle,
            tier: 4,
            builtDescription: "12th century (fortress from 2nd millennium BC)",
            civilisation: "Kingdom of Scotland",
            tagline: "900 years of Scottish history in stone",
            chapters: [
                Chapter(
                    id: "edinburgh-castle-overview",
                    title: "Overview",
                    eyebrow: "The Rock of Scotland",
                    heading: "Never taken by a direct assault in 900 years",
                    body: "<p>Edinburgh Castle sits atop <strong>Castle Rock</strong> — a volcanic plug formed 350 million years ago. The first fortifications appeared in the <strong>12th century</strong> under King David I. The castle has been besieged 26 times in its history, but was never taken by direct assault — only by treachery or starvation.</p><p>Within its walls: the Scottish Crown Jewels (the oldest surviving crown jewels in Britain), the Stone of Destiny upon which Scottish — and later British — monarchs were crowned, and St Margaret's Chapel, built in 1130 and the oldest surviving building in Edinburgh.</p>",
                    facts: [
                        Fact(label: "Rock formed", value: "350 million years ago"),
                        Fact(label: "First fortified", value: "12th century AD"),
                        Fact(label: "Times besieged", value: "26 recorded sieges"),
                        Fact(label: "Crown Jewels", value: "Oldest in Britain (Scottish Honours)"),
                    ]
                ),
            ],
            nearestAirport: "Edinburgh Airport (EDI)",
            bestTimeToVisit: "May–September",
            visaNote: "UK — ETA required for most non-UK/Irish visitors from 2024"
        ),
        Site(
            id: "alhambra",
            name: "Alhambra",
            location: "Granada, Spain",
            latitude: 37.18,
            longitude: -3.59,
            era: .medieval,
            type: .wonder,
            tier: 5,
            builtDescription: "13th–14th century AD",
            civilisation: "Nasrid Emirate of Granada",
            tagline: "The last jewel of Islamic Spain",
            chapters: [
                Chapter(
                    id: "alhambra-overview",
                    title: "Overview",
                    eyebrow: "The Red Fortress",
                    heading: "Islam's last great monument in Europe",
                    body: "<p>The Alhambra — meaning \"the red one\" in Arabic, for the colour of its walls — was built by the <strong>Nasrid Dynasty</strong> as their royal palace and fortress from 1238 to 1358. It was the last great Muslim kingdom in Europe, surviving two centuries after the Christian Reconquista swept south.</p><p>The palace interiors are among the most breathtaking achievements in human architecture: honeycombed stucco ceilings containing <strong>8,000 individual muqarnas cells</strong>, geometric tilework, calligraphic panels, and the Court of the Lions — a marble fountain system of extraordinary hydraulic sophistication.</p>",
                    facts: [
                        Fact(label: "Built", value: "1238–1358 AD"),
                        Fact(label: "Builders", value: "Nasrid Dynasty (Moorish)"),
                        Fact(label: "Fell to Christians", value: "2 January 1492"),
                        Fact(label: "UNESCO listed", value: "1984"),
                    ]
                ),
            ],
            nearestAirport: "Federico García Lorca Airport (GRX)",
            bestTimeToVisit: "April–June or September–October",
            visaNote: "EU/Schengen"
        ),
        Site(
            id: "terracotta-army",
            name: "Terracotta Army",
            location: "Xi'an, Shaanxi, China",
            latitude: 34.38,
            longitude: 109.27,
            era: .ancient,
            type: .treasure,
            tier: 5,
            builtDescription: "c. 246–208 BC",
            civilisation: "Qin Dynasty",
            tagline: "8,000 warriors for an emperor's afterlife",
            chapters: [
                Chapter(
                    id: "terracotta-army-overview",
                    title: "Overview",
                    eyebrow: "The First Emperor's Army",
                    heading: "A buried army of 8,000 unique soldiers",
                    body: "<p>Emperor <strong>Qin Shi Huang</strong> — the first emperor of a unified China — ordered construction of his mausoleum complex when he was just 13 years old. At its heart was an army of <strong>8,000 life-sized terracotta soldiers</strong>, each with a unique face, ranked by function: infantry, cavalry, archers, charioteers, and generals.</p><p>They were discovered entirely by accident on <strong>29 March 1974</strong> by farmers digging a well. The largest pit alone contains 6,000 figures. After 2,200 years underground, the army still stands in formation — waiting.</p>",
                    facts: [
                        Fact(label: "Built", value: "246–206 BC"),
                        Fact(label: "Total soldiers", value: "~8,000 unique figures"),
                        Fact(label: "Discovered", value: "29 March 1974"),
                        Fact(label: "Discovered by", value: "Farmers digging a well"),
                    ]
                ),
            ],
            nearestAirport: "Xi'an Xianyang International (XIY)",
            bestTimeToVisit: "March–May or September–November",
            visaNote: "Visa-free transit for qualifying nationalities; standard visa otherwise"
        ),
        Site(
            id: "stonehenge",
            name: "Stonehenge",
            location: "Wiltshire, England",
            latitude: 51.18,
            longitude: -1.83,
            era: .ancient,
            type: .sacred,
            tier: 5,
            builtDescription: "3000–1500 BC",
            civilisation: "Neolithic / Bronze Age Britons",
            tagline: "The mystery the millennia could not answer",
            chapters: [
                Chapter(
                    id: "stonehenge-overview",
                    title: "Overview",
                    eyebrow: "The Mystery of Salisbury Plain",
                    heading: "No written record. No clear purpose. Perfect alignment.",
                    body: "<p>Stonehenge was built in three phases over <strong>1,500 years</strong>, beginning around 3000 BC. The largest sarsen stones — each weighing 25 tonnes — were transported from Marlborough Downs 25 miles away. The bluestones came from <strong>Wales, 150 miles away</strong>, a feat of prehistoric logistics that remains unexplained.</p><p>At sunrise on the summer solstice, the sun rises directly over the Heel Stone and illuminates the altar stone at the monument's centre. The alignment is exact to within fractions of a degree. Whatever Stonehenge was — a calendar, a temple, a burial ground — it was built by people who understood their sky.</p>",
                    facts: [
                        Fact(label: "Built", value: "3000–1500 BC"),
                        Fact(label: "Sarsen stone weight", value: "Up to 25 tonnes"),
                        Fact(label: "Bluestone origin", value: "Preseli Hills, Wales (150 miles)"),
                        Fact(label: "Alignment", value: "Summer solstice sunrise — exact"),
                    ]
                ),
            ],
            nearestAirport: "London Heathrow (LHR) or Southampton (SOU)",
            bestTimeToVisit: "May–September (summer solstice access special)",
            visaNote: "UK — ETA required for most non-UK/Irish visitors from 2024"
        ),
        Site(
            id: "chichen-itza",
            name: "Chichen Itza",
            location: "Yucatán, Mexico",
            latitude: 20.68,
            longitude: -88.57,
            era: .medieval,
            type: .wonder,
            tier: 5,
            builtDescription: "c. 600–1200 AD",
            civilisation: "Maya Civilisation",
            tagline: "Where the serpent descends at equinox",
            chapters: [
                Chapter(
                    id: "chichen-itza-overview",
                    title: "Overview",
                    eyebrow: "The Feathered Serpent",
                    heading: "A pyramid that becomes a calendar twice a year",
                    body: "<p>El Castillo — the pyramid of Kukulkan — was built by the Maya with a precision that seems impossible. It has <strong>365 steps</strong>, one for each day of the year. On the spring and autumn equinoxes, the afternoon sun creates a shadow pattern on the north staircase that makes a serpent appear to descend from sky to earth — the feathered god <strong>Kukulkan</strong> returning.</p><p>The effect is caused by triangular shadows cast by the nine stepped platforms. It lasts for 45 minutes. Thousands gather to watch it every equinox. No accident — it is 1,000-year-old engineering.</p>",
                    facts: [
                        Fact(label: "Built", value: "600–1200 AD"),
                        Fact(label: "Pyramid steps", value: "365 (one per day)"),
                        Fact(label: "Equinox effect", value: "Serpent shadow, 45 minutes"),
                        Fact(label: "UNESCO listed", value: "1988"),
                    ]
                ),
            ],
            nearestAirport: "Cancún International (CUN)",
            bestTimeToVisit: "December–April",
            visaNote: "Visa-free for most Western passports up to 180 days"
        ),
        Site(
            id: "hagia-sophia",
            name: "Hagia Sophia",
            location: "Istanbul, Turkey",
            latitude: 41.01,
            longitude: 28.98,
            era: .classical,
            type: .sacred,
            tier: 5,
            builtDescription: "532–537 AD",
            civilisation: "Byzantine Empire",
            tagline: "1,400 years as church, mosque, and museum",
            chapters: [
                Chapter(
                    id: "hagia-sophia-overview",
                    title: "Overview",
                    eyebrow: "Holy Wisdom",
                    heading: "For 1,000 years, the largest enclosed space on Earth",
                    body: "<p>Emperor <strong>Justinian I</strong> completed the Hagia Sophia — Church of Holy Wisdom — in just <strong>five years</strong> (532–537 AD). Its dome, 55 metres high and 31 metres across, appeared to float on a ring of 40 windows flooding the interior with light. For nearly 1,000 years it was the largest enclosed space on Earth.</p><p>When Constantinople fell to the Ottomans in <strong>1453</strong>, Sultan Mehmed II entered and converted it to a mosque within hours. In 1934, Ataturk made it a secular museum. In 2020, Turkey converted it back to a mosque — a controversy that continues today.</p>",
                    facts: [
                        Fact(label: "Built", value: "532–537 AD (5 years)"),
                        Fact(label: "Dome diameter", value: "31 metres"),
                        Fact(label: "Dome height", value: "55 metres"),
                        Fact(label: "Converted to mosque", value: "1453 (Ottoman conquest)"),
                    ]
                ),
            ],
            nearestAirport: nil,
            bestTimeToVisit: nil,
            visaNote: nil
        ),
    ]
}
