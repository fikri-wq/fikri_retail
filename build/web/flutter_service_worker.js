'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "993f48ad92a513f2e6206904f4adcf4b",
"assets/AssetManifest.bin.json": "8ecdf58d359335031d2ffa247bbc080f",
"assets/AssetManifest.json": "73db9529964af078778a7fcb562c9b58",
"assets/assets/AN.png": "c34ae41eef96bf0a4593e4ea5365c167",
"assets/assets/AN1.jpg": "dc43ad3ffe9082b23e833ee6380753ed",
"assets/assets/AN2.png": "ad84d515850c24b7b4464e067a3addb7",
"assets/assets/AN3.png": "adaca0d9a49e0cf8da3e2069c58bb9ab",
"assets/assets/AN4.png": "856656d0989ac6c8b4da7bd26c69b94f",
"assets/assets/aneka%2520supermi.jpg": "aaa780e1173bd223d011de8b7f2a9a30",
"assets/assets/bca.jpg": "fb98656be10fc563c9f36bcbe4a4ea13",
"assets/assets/Beras%25205kg%2520Cap%2520Jago.jpg": "ca2e8819527e837ee641bfeea632e1ff",
"assets/assets/Bimoli%25202L.jpg": "8e5a5ef9bc8deba4147f22c7a7317fd3",
"assets/assets/Bimoli%2520Klasik%25201L.jpg": "be6789a86358d49443ea56ddd80a8751",
"assets/assets/Bimoli%2520Spesial%25201L.jpg": "a60fc673a189a48a5114e72293959faa",
"assets/assets/bni.png": "941fbbf401bc677cad3ee44b8d1213b5",
"assets/assets/bri.png": "c67b7d44a1eff5e7925166eb2c4a500d",
"assets/assets/Bumbu%2520Racik%2520Ayam%2520Goreng%2520Indofood.jpg": "97de12ff64ef3f29b7528d0ae661c455",
"assets/assets/Bumbu%2520Racik%2520Nasi%2520Goreng%2520Indofood.jpg": "5740d5cb9c15c39b872d63913de8ed55",
"assets/assets/Bumbu%2520Racik%2520Rendang%2520Indofood.jpg": "0c09b32fe48ea9d81811d49d29ae204d",
"assets/assets/Cap%2520Enaak%2520Kental%2520Manis%2520370g.jpg": "cdd91fe2481fd88fe1b3cefc54eff9dc",
"assets/assets/Cheetos%2520Jagung%2520Bakar%252040g.jpg": "d18e596f264eb527b02606d326da12a6",
"assets/assets/Chitato%2520Ayam%2520BBQ%252068g.jpg": "56ca95f7cf7b9160633e935fa2cf7898",
"assets/assets/Chitato%2520Lite%2520Rumput%2520Laut%252068g.jpg": "4328cc28642fff0ec757cb63deb71286",
"assets/assets/Chitato%2520Sapi%2520Panggang%252068g.jpg": "e3780a51d19743f4b4dea9d438bd5bc8",
"assets/assets/Club%2520Air%2520Mineral%25201500ml.jpg": "e8fd42a1578c573d17adeb4b513f22c9",
"assets/assets/Club%2520Air%2520Mineral%2520600ml.jpg": "1e2c242b307a3b4400e5473221050971",
"assets/assets/dana.png": "13dcfd2551fc1e1f74b65e83853fc54f",
"assets/assets/Gula%2520Pasir%2520Indofood%25201kg.jpg": "17df22e605ad507fd6ff03c11b478904",
"assets/assets/Ichi%2520Ocha%2520Teh%2520Hijau%2520350ml.jpg": "99e0a2b0e50309de17c1b28c42490ce2",
"assets/assets/iklan%25202.jpg": "6573e1177d85ce10d287fc75163c3a30",
"assets/assets/iklan%25203.jpg": "0cab71decbe434df18c7153b5aeb87de",
"assets/assets/iklan%25204.jpg": "a7e0bcfdb5702a1faa0a0e5c6f1e62ea",
"assets/assets/iklan%25205.jpg": "b56532305d3b7e4cdd2be0ee8c0dfa98",
"assets/assets/iklan%25206.jpg": "0d51ff1b9691eba711151b213d9fb924",
"assets/assets/iklan%25207.jpg": "ab784cdf37ad756e6b84f853912af7f3",
"assets/assets/iklan%25208.png": "c8ef06d3e4e5fccd4e73dc2fd027e80e",
"assets/assets/iklan1.jpg": "80106b0799f19168fedcf705ccafcfe2",
"assets/assets/Indofood%2520Freiss%2520Syrup%2520Cocopandan%2520650ml.jpg": "6287530853a017266cb4815fbbed7da2",
"assets/assets/Indomie%2520Goreng%2520Original.jpg": "2963be7e79efd8403d9929215407f19a",
"assets/assets/Indomie%2520Goreng%2520Pedas.jpg": "06461bec5af1a704b495b65e13d563db",
"assets/assets/Indomie%2520Hype%2520Abis%2520Ayam%2520Geprek.jpg": "f6fd41963a34335b9a259a843af0de95",
"assets/assets/Indomie%2520Kuah%2520Ayam%2520Bawang.jpg": "a3d74543b45e4d2f4c8f2c6ca92e9f5f",
"assets/assets/Indomie%2520Kuah%2520Kari%2520Ayam.jpg": "791a042bc674a2f72e9fec60a1c0384b",
"assets/assets/Indomie%2520Kuah%2520Soto.jpg": "4839b443800c7f4c5a012f4cd31fd042",
"assets/assets/Indomilk%2520Susu%2520Kental%2520Manis%2520385g.jpg": "e17db4ed2eec1ff6267e99d7278ffe86",
"assets/assets/indomilk%2520UHT%2520Cokelat%2520250ml.jpg": "f7c0332bc9a963fba7efa795d5790c5e",
"assets/assets/Indomilk%2520UHT%2520Full%2520Cream%25201L.jpg": "767755085c6730bf827b32d9017a05d3",
"assets/assets/Kecap%2520Manis%2520Indofood%2520135ml.jpg": "d8bc47d861d9e5b952e9f8d14bfb2678",
"assets/assets/Kecap%2520Manis%2520Indofood%2520275ml.jpg": "f83c3aa0757203e54c17f5d550c172e8",
"assets/assets/kremer%2520Kental%2520Manis%2520380g.jpg": "a676b4dbe5451dce92d5727b324eb8d8",
"assets/assets/Lays%2520Rumput%2520Laut%252068g.jpg": "6758a93592a10a33b15b7c3b104a502e",
"assets/assets/LOGO.png": "7c92d4b04a6a16289e9acc8091fcc3ae",
"assets/assets/logo1.jpg": "72f8d7d8cd091713e6564fd9cc3d14e3",
"assets/assets/mandiri.png": "85ff41c2d1df4beb643e683a90cd1bcd",
"assets/assets/Piring%2520Lombok%2520Sambal%2520Terasi%2520275ml.jpg": "a346c5151beb19962c5d6bf12a9cbd68",
"assets/assets/Pop%2520Mie%2520Goreng%2520Pedes.jpg": "b4af30da28559f269ef257ab116afeba",
"assets/assets/Pop%2520Mie%2520Kuah%2520Ayam.jpg": "898c7f33ba1da9c7f3547b2febc20bac",
"assets/assets/products/AIR_MINERAL/AQUA/Botol_-_1.5L.jpeg": "b7b4cb91b4992c8a39a314944b21c565",
"assets/assets/products/AIR_MINERAL/AQUA/Botol_-_330ml.jpeg": "7f4635988d55838731f3034bbd98640a",
"assets/assets/products/AIR_MINERAL/AQUA/Botol_-_600ml.jpeg": "24354287f0c655bf3ff1a54db43f1f7e",
"assets/assets/products/AIR_MINERAL/AQUA/Galon_-_19L.jpeg": "0c9fd19945c35fc20b41edaaddec7dfc",
"assets/assets/products/AIR_MINERAL/AQUA/Gelas_-_220ml.jpeg": "778bf0af4649c9f5b7433542dcff9681",
"assets/assets/products/AIR_MINERAL/CLEO/Botol_-_1.2L.jpeg": "02384840679c05fb5da027be235c5c26",
"assets/assets/products/AIR_MINERAL/CLEO/Botol_-_220ml.jpeg": "bde3b08f67e0964743f1fa800a6035b3",
"assets/assets/products/AIR_MINERAL/CLEO/Botol_-_550ml.jpeg": "f19ac032421f8ff420beae373cc682e4",
"assets/assets/products/AIR_MINERAL/CLEO/Galon_-_19L.jpeg": "9eb9d409fc7f20aca1485c88a4073a5e",
"assets/assets/products/AIR_MINERAL/CLUB/Botol_-_1.5L.jpeg": "e8fd42a1578c573d17adeb4b513f22c9",
"assets/assets/products/AIR_MINERAL/CLUB/Botol_-_600ml.jpeg": "1e2c242b307a3b4400e5473221050971",
"assets/assets/products/AIR_MINERAL/CLUB/Galon_-_19L.jpeg": "0a98e37da93ed9a7f0c345a082ddf0c5",
"assets/assets/products/AIR_MINERAL/CLUB/Gelas_-_220ml.jpeg": "46f4268458368bbf35481c55b4b03e61",
"assets/assets/products/AIR_MINERAL/LE_MINERALE/Botol_-_1.5L.jpeg": "5b5a6356a277760f20f8ef869415edf1",
"assets/assets/products/AIR_MINERAL/LE_MINERALE/Botol_-_330ml.jpeg": "735d833dadfd3388d4bbc7c860da3743",
"assets/assets/products/AIR_MINERAL/LE_MINERALE/Botol_-_600ml.jpeg": "3b8b61dd73e5385405cda726edd46a26",
"assets/assets/products/AIR_MINERAL/LE_MINERALE/Galon_-_15L.jpeg": "6b32f3cc7aab3ab5b231bc943390269a",
"assets/assets/products/AIR_MINERAL/VIT/Botol_-_1.5L.jpeg": "a2620d9f2cb7812a584b7f7560d07184",
"assets/assets/products/AIR_MINERAL/VIT/Botol_-_330ml.jpeg": "bccf54c7fdcc31f0b8638186ff15885b",
"assets/assets/products/AIR_MINERAL/VIT/Botol_-_600ml.jpeg": "22e53366bf495eb7135e001329a0d188",
"assets/assets/products/AIR_MINERAL/VIT/Galon_-_19L.jpeg": "b63614fc6235b255283dc2416c28f610",
"assets/assets/products/BUMBU_MASAK/BANGOABCINDOFOOD/ABC_Kecap_Manis_-_botol.jpeg": "b3d0d375c6f570ad41e1d11b0399a0f3",
"assets/assets/products/BUMBU_MASAK/BANGOABCINDOFOOD/ABC_Saus_Sambal_-_botol.jpeg": "0cf08e767241107506ceeee613596023",
"assets/assets/products/BUMBU_MASAK/BANGOABCINDOFOOD/ABC_Saus_Tomat_-_botol.jpeg": "dfc1c1284c0e4374c00c28f9cb5d38d1",
"assets/assets/products/BUMBU_MASAK/BANGOABCINDOFOOD/Bango_Kecap_Manis_-_275m.jpeg": "830494e15b45880d9dc53d16ee15d50d",
"assets/assets/products/BUMBU_MASAK/BANGOABCINDOFOOD/Indofood_Sambal_Pedas_-_botol.jpeg": "fc807bf80e399ac7a20ac4933be94f15",
"assets/assets/products/BUMBU_MASAK/BANGOABCINDOFOOD/Indofood_Saus_Tomat_-_botol.jpeg": "c99e4130001b63df8f0cb04639c52757",
"assets/assets/products/BUMBU_MASAK/INDOFOOD_RACIK/Ayam_Goreng_-_sachet.jpeg": "bb3bbad816b99bdd46cba321b50602fd",
"assets/assets/products/BUMBU_MASAK/INDOFOOD_RACIK/Ikan_Goreng_-_sachet.jpeg": "b0bad4227c0f0af65293f1ed49a42505",
"assets/assets/products/BUMBU_MASAK/INDOFOOD_RACIK/Nasi_Goreng_-_sachet.jpeg": "073d07d6c63df51e60c71c0b0a92f693",
"assets/assets/products/BUMBU_MASAK/INDOFOOD_RACIK/Sayur_Asem_-_sachet.jpeg": "d35bfbd5d72b4cf65278941ebe816048",
"assets/assets/products/BUMBU_MASAK/INDOFOOD_RACIK/Sayur_Sop_-_sachet.jpeg": "a1a0d6c02220a253515a28d67cf501bf",
"assets/assets/products/BUMBU_MASAK/INDOFOOD_RACIK/Tempe_Goreng_-_sachet.jpeg": "1236e1417a91bdcd3721cf2d150db28f",
"assets/assets/products/BUMBU_MASAK/KOBE/BonCabe_Level_10_-_botol.jpeg": "aade94cf72d73f39d0caacb0b5311511",
"assets/assets/products/BUMBU_MASAK/KOBE/BonCabe_Level_15_-_botol.jpeg": "a2ef99eedebdc7ecd31b95da382c1e6e",
"assets/assets/products/BUMBU_MASAK/KOBE/BonCabe_Level_30_-_botol.jpeg": "36cfbeaf86996b9049dc51a2eab00131",
"assets/assets/products/BUMBU_MASAK/KOBE/Nasi_Goreng_Poll_Pedas_-_sachet.jpeg": "6a5523a0336b9c797a3ccde14d227aa7",
"assets/assets/products/BUMBU_MASAK/KOBE/Tepung_Bakwan_-_75g.jpeg": "e39dce4ab938b8f70a7af14982545bf7",
"assets/assets/products/BUMBU_MASAK/KOBE/Tepung_Kentucky_Super_Crispy_-_210g.jpeg": "ceec81334a5c46c398aea89ba250096c",
"assets/assets/products/BUMBU_MASAK/MASAKO/Ayam_-_sachet.jpeg": "84954c34c092729d240da761d9d2b2e1",
"assets/assets/products/BUMBU_MASAK/MASAKO/Rasa_Gurih_-_sachet.jpeg": "388bdc39aac246721ee61286de03cd0a",
"assets/assets/products/BUMBU_MASAK/MASAKO/Sapi_-_sachet.jpeg": "cd1ec063389888fd70372e3df7c11a9c",
"assets/assets/products/BUMBU_MASAK/ROYCO/Ayam_-_sachet.jpeg": "d618276d27fc21be03a5b7c415335bb7",
"assets/assets/products/BUMBU_MASAK/ROYCO/Kaldu_Jamur_-_sachet.jpeg": "efb037c60ad98662d7af389e568ba862",
"assets/assets/products/BUMBU_MASAK/ROYCO/Sapi_-_sachet.jpeg": "fc32a88b685db69e99b8a7f22eefbf6e",
"assets/assets/products/BUMBU_MASAK/ROYCO/Sup_Krim_Ayam_-_sachet.jpeg": "1e05d9fee0691e91d95055d093c243d2",
"assets/assets/products/BUMBU_MASAK/SAJIKU/Capcay_-_sachet.jpeg": "0cf59d2deb2c4c58c358dd5f499acffe",
"assets/assets/products/BUMBU_MASAK/SAJIKU/Nasi_Goreng_Ayam_-_sachet.jpeg": "8af6535bcdb9130ef9a4d6b3061d31c5",
"assets/assets/products/BUMBU_MASAK/SAJIKU/Nasi_Goreng_Pedas_-_sachet.jpeg": "ee5796e476df18ba2c1335ad53fbd46e",
"assets/assets/products/BUMBU_MASAK/SAJIKU/Sayur_Sop_-_sachet.jpeg": "975dc70bab4889ee962731e542a5797f",
"assets/assets/products/BUMBU_MASAK/SAJIKU/Tepung_Bumbu_Original_-_80g.jpeg": "dd648da6c82a900e15b605714c804970",
"assets/assets/products/BUMBU_MASAK/SAJIKU/Tepung_Bumbu_Pedas_-_80g.jpeg": "54632af3b8fb56c9af18b2bb6f143d0d",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/ATTACK/Batik_Care_-_700g.jpeg": "0e0deac36e4036eb74a6ac388feed365",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/ATTACK/Easy_-_800g.jpeg": "97abfa96cea98b2bc2e536764f8239d6",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/ATTACK/Jaz1_-_800g.jpeg": "bd4d0ef21a65c74b95e88954abf99390",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/ATTACK/Liquid_-_800ml.jpeg": "ad5735787bd3b85164c6cae5487a0a06",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/DAIA/Lemon_-_850g.jpeg": "02df3030e37b81d2f82c468080f73f16",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/DAIA/Putih_-_850g.jpeg": "cd4f9ef7c5fb7932157bcd37c7d69ecf",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/DAIA/Softener_-_850g.jpeg": "cccfeaff9163098edc12197dab3402f3",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/DAIA/Violet_-_850g.jpeg": "71574bc3ea3c69afa05b253e239a7493",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/DOWNY/Anti_Apek_-_botol.jpeg": "c70e9a34a90cfd51d4376159d2b0f3fc",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/DOWNY/Mystique_-_botol.jpeg": "f2a9271790d3d2eba8d185f6e1fc669b",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/DOWNY/Passion_-_botol.jpeg": "55d4d0d9d3238f208dd5c3e6ce6199be",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/DOWNY/Sunrise_Fresh_-_botol.jpeg": "7eaf588af7a367e2b21772a5807634cb",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/MOLTO/All_in_1_-_800ml.jpeg": "6925ab0d0e4e8e8c2819fcb43c96da0c",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/MOLTO/Eau_de_Parfum_-_botol.jpeg": "9d81ec8ba233170d9c341ee6dd43efc6",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/MOLTO/Pewangi_Biru_-_botol.jpeg": "2cda4945660c59f70402346b26ed71e8",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/MOLTO/Pewangi_Pink_-_botol.jpeg": "7646350a08a87bdada04db6f50b7a013",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/RINSO/Anti_Noda_Bubuk_-_770g.jpeg": "fa997ac8355f47054db387a1f911a8cd",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/RINSO/Cair_Anti_Noda_-_770ml.jpeg": "c46d955dff90dfdc27642908f43c047b",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/RINSO/Matic_Front_Load_-_1L.jpeg": "944f1562504885ff1135c277553638d8",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/RINSO/Matic_Top_Load_-_1L.jpeg": "94123a03d8f4de1d19f9bd71589d68e9",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/RINSO/Molto_Bubuk_-_770g.jpeg": "f57ef22a4c85edbacb9b32e5c7a2859f",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/SO_KLIN/Bio-Matic_-_800g.jpeg": "98d6c897202d59a95f2c8395ad4ae1eb",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/SO_KLIN/Liquid_-_800ml.jpeg": "fa6b12e918a64bed0a95d17e028b6e67",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/SO_KLIN/Softergent_Pink_-_770g.jpeg": "bfc8cee0a1e3df7f6bf06dcc300fcac4",
"assets/assets/products/DETERGEN_DAN_LAUNDRY/SO_KLIN/Softergent_Ungu_-_770g.jpeg": "411284aa5e6c4fcb7505c75e51b24172",
"assets/assets/products/FROZEN_FOOD/BELFOODS/Bakso_Ayam_-_pack.jpeg": "cc63949cb1cee41c411287b3e167bee5",
"assets/assets/products/FROZEN_FOOD/BELFOODS/Chicken_Nugget_-_500g.jpeg": "8240b1a0d0c765fcc569cfe3afd89d2f",
"assets/assets/products/FROZEN_FOOD/BELFOODS/Royal_Nugget_-_pack.jpeg": "4eddb33cd70861d791e4c0ae202a31bb",
"assets/assets/products/FROZEN_FOOD/BELFOODS/Sosis_Ayam_-_pack.jpeg": "25a20fccd165cb44bd167d657c884f0d",
"assets/assets/products/FROZEN_FOOD/BERNARDI/Bakso_Sapi_-_pack.jpeg": "d1e18190fc42f427c73bb48f3a907f9a",
"assets/assets/products/FROZEN_FOOD/BERNARDI/Burger_Patty_-_pack.jpeg": "b957fb0174494fbdd4f0c9c9db919a4f",
"assets/assets/products/FROZEN_FOOD/BERNARDI/Sosis_Ayam_-_pack.jpeg": "380ca646a80c6be75b92ab1c244887fd",
"assets/assets/products/FROZEN_FOOD/BERNARDI/Sosis_Sapi_-_pack.jpeg": "e5008d2df6a9df369388951e6c6bc817",
"assets/assets/products/FROZEN_FOOD/CHAMP/Chicken_Ball_-_pack.jpeg": "866e387d0f400dd03930bc8aa772356c",
"assets/assets/products/FROZEN_FOOD/CHAMP/Chicken_Nugget_-_500g.jpeg": "67f1503f4ec31cd692964142ae9336fc",
"assets/assets/products/FROZEN_FOOD/CHAMP/Sosis_Ayam_-_pack.jpeg": "2ce51320e800d86439c38953192095a9",
"assets/assets/products/FROZEN_FOOD/CHAMP/Sosis_Sapi_-_pack.jpeg": "11bc4b031fff7dec9c3181b0d8326fd8",
"assets/assets/products/FROZEN_FOOD/FIESTA/Chicken_Nugget_-_500g.jpeg": "01c63711be6111634761e89add5a1dab",
"assets/assets/products/FROZEN_FOOD/FIESTA/Chicken_Sausage_-_pack.jpeg": "ac0ae472e5a6ce8373472986903b40ff",
"assets/assets/products/FROZEN_FOOD/FIESTA/French_Fries_-_500g.jpeg": "c56486eb570f2d7f172c54f64477b287",
"assets/assets/products/FROZEN_FOOD/FIESTA/Karage_-_500g.jpeg": "958d0828972fc1cf0a2c24f84db8b016",
"assets/assets/products/FROZEN_FOOD/FIESTA/Spicy_Nugget_-_500g.jpeg": "f57669755560b93a28cf100708fa4107",
"assets/assets/products/FROZEN_FOOD/KANZLER/Beef_Cocktail_Sausage_-_pack.jpeg": "54c45179b10137ae8aa0331e71ce6d1b",
"assets/assets/products/FROZEN_FOOD/KANZLER/Chicken_Nugget_-_pack.jpeg": "3dbee18bd52d8598b600b3410616faee",
"assets/assets/products/FROZEN_FOOD/KANZLER/Crispy_Chicken_Nugget_-_pack.jpeg": "207a1875d9026a0839fc8f6bead1484b",
"assets/assets/products/FROZEN_FOOD/KANZLER/Single_Hot_-_pcs.jpeg": "7cef9b11236aed401163d588387d7188",
"assets/assets/products/FROZEN_FOOD/KANZLER/Single_Original_-_pcs.jpeg": "259206f4332aa6b4b1dd8b5a9f64eddd",
"assets/assets/products/FROZEN_FOOD/SO_GOOD/Chicken_Nugget_Alphabet_-_400g.jpeg": "3b3acb1f4f72684d34ef2000e2006b8c",
"assets/assets/products/FROZEN_FOOD/SO_GOOD/Chicken_Nugget_Original_-_400g.jpeg": "6783d27196c12fc5bfc47a96f91f040a",
"assets/assets/products/FROZEN_FOOD/SO_GOOD/Chicken_Wings_-_400g.jpeg": "d27f5cbf3de30679f79a725e8414dd01",
"assets/assets/products/FROZEN_FOOD/SO_GOOD/Sosis_Ayam_-_pack.jpeg": "053769d1c9d47a06462d708e96968a10",
"assets/assets/products/FROZEN_FOOD/SO_GOOD/Spicy_Chicken_Nugget_-_400g.jpeg": "d405ffd32f316803451def783e5d2091",
"assets/assets/products/KOPI/ABC/Kopi_Gula_Aren_-_sachet.jpeg": "c78bced1effda2d354fda05e923270a0",
"assets/assets/products/KOPI/ABC/Kopi_Susu_-_sachet.jpeg": "973c70a174c8749d77397bab58b82221",
"assets/assets/products/KOPI/ABC/Kopi_Tubruk_-_sachet.jpeg": "8663ad863ddba9c8f4d3bf1f3bfbf9b4",
"assets/assets/products/KOPI/ABC/Mocca_-_sachet.jpeg": "ca534399c175652a937f1d3f4c9e34c0",
"assets/assets/products/KOPI/ABC/White_Coffee_-_sachet.jpeg": "d41ef8a4c27ce5d2cca9465cceac8e08",
"assets/assets/products/KOPI/GOOD_DAY/Cappuccino_-_sachet.jpeg": "0a701e383e756cc5dbd6dafb633919a0",
"assets/assets/products/KOPI/GOOD_DAY/Chococinno_-_sachet.jpeg": "b7a0909f0b836e89eb77cdc09a71ca88",
"assets/assets/products/KOPI/GOOD_DAY/Coffee_Drink_-_250ml.jpeg": "1ea4fb57a8d41424c8e8b5ffe3d6b1a5",
"assets/assets/products/KOPI/GOOD_DAY/Freeze_Mocafrio_-_sachet.jpeg": "95054c03b131a9bb7e92c3faa8cd4175",
"assets/assets/products/KOPI/GOOD_DAY/Mocacinno_-_sachet.jpeg": "5a45dbc0aec817f299b2bb3c8011ae44",
"assets/assets/products/KOPI/GOOD_DAY/Vanilla_Latte_-_sachet.jpeg": "12f31117ef1024a7159bc0677a624db5",
"assets/assets/products/KOPI/KAPAL_API/Bubuk_Special_-_380g.jpeg": "405e455f4d98eb937d5e69ac50be3dcf",
"assets/assets/products/KOPI/KAPAL_API/Grande_White_Coffee_-_sachet.jpeg": "a5e6300d7218e9ec8cbe1f98feb2f6b2",
"assets/assets/products/KOPI/KAPAL_API/Kopi_Hitam_-_sachet.jpeg": "6dc2e8a48b67b464084a5d1b5239f107",
"assets/assets/products/KOPI/KAPAL_API/Less_Sugar_-_sachet.jpeg": "726707e2fc3384bdb5cd3ce079dd9414",
"assets/assets/products/KOPI/KAPAL_API/Mantap_-_sachet.jpeg": "f3368c834cf766eb62c0346a82849853",
"assets/assets/products/KOPI/KAPAL_API/Special_Mix_-_sachet.jpeg": "adf7b4f026ab3be03afdddf7226eda4d",
"assets/assets/products/KOPI/LUWAK_WHITE_COFFE/Less_Sugar_-_sachet.jpeg": "6d3bc28f4b8a164e9db57843c2009355",
"assets/assets/products/KOPI/LUWAK_WHITE_COFFE/Original_-_sachet.jpeg": "dead8307ab2a959d22945efe2b6fea75",
"assets/assets/products/KOPI/LUWAK_WHITE_COFFE/Tarik_Malaka_-_sachet.jpeg": "880287353fc1fd2432bbdd26378401be",
"assets/assets/products/KOPI/NESCAFE/3_in_1_Original_-_sachet.jpeg": "4238cd0f0781a90e5e3923d690cc6f94",
"assets/assets/products/KOPI/NESCAFE/Classic_-_sachet.jpeg": "f97db7754f177862e0ddc43dffaa84dc",
"assets/assets/products/KOPI/NESCAFE/Latte_-_sachet.jpeg": "7dd92f926b54638cde23cdd4b706fd9d",
"assets/assets/products/KOPI/NESCAFE/Ready_to_Drink_-_kaleng.jpeg": "28624e26bb88c49af9f8d7488204af68",
"assets/assets/products/KOPI/TORABIKA/Cappuccino_-_sachet.jpeg": "a456f8790fe1c475bdd6704bcd72c038",
"assets/assets/products/KOPI/TORABIKA/Creamy_Latte_-_sachet.jpeg": "ba00b14634bfc20446faae5025341026",
"assets/assets/products/KOPI/TORABIKA/Duo_-_sachet.jpeg": "594542eefae4491efa3626d653ecd655",
"assets/assets/products/KOPI/TORABIKA/Jahe_Susu_-_sachet.jpeg": "23b2bf379f4100f88f9cd2a529b090e6",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/ABC/Mackerel_Saus_Cabai_-_425g.jpeg": "945bb24817e07c9088007b3fa9f24d92",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/ABC/Mackerel_Saus_Tomat_-_425g.jpeg": "6af8cc23576f3ec2920ad11e14ea5585",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/ABC/Sardines_Saus_Cabai_-_425g.jpeg": "21be9dc0a9e5fa3ae7c1bbcb72e2f153",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/ABC/Sardines_Saus_Tomat_-_425g.jpeg": "e1b496dc5bf7ece1235117a5830c5fac",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/BOTAN/Mackerel_-_155g.jpeg": "cd8f0834d2d0b26124d7cf960684b17c",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/BOTAN/Sardines_Tomat_-_155g.jpeg": "f2d4dcd3c0c4c622f0711133c6cf46d6",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/BOTAN/Tuna_Flakes_-_kaleng.jpeg": "ee216e3771c15c9b074e4ad1816ce4db",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/PRONAS/Corned_Beef_-_198g.jpeg": "84f49676e119b98d1d6d783197bc53eb",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/PRONAS/Corned_Chicken_-_120g.jpeg": "5907d3a51d0ed2992ab9d61f159dea0b",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/PRONAS/Luncheon_Meat_-_kaleng.jpeg": "92d117d14958b1e46e837b99beea7b74",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/QUAKER/Oat_Instant_-_400g.jpeg": "90029a1ff1004472ac883690988bd2b8",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/QUAKER/Oat_Quick_Cook_-_400g.jpeg": "4f5266cff11b72a39a69961231ca77ef",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/QUAKER/Sachet_Chocolate_-_sachet.jpeg": "f0062e049cad3365a873224d60abb377",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/QUAKER/Sachet_Strawberry_-_sachet.jpeg": "feedab31310681bb2d2e7214aa889325",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/SUPER_BUBUR/Ayam_-_sachet.jpeg": "91946e6d367e5a3695b8c5727954505c",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/SUPER_BUBUR/Kari_Ayam_-_cup.jpeg": "8f90bbca8a7643822266dd2100e7455e",
"assets/assets/products/MAKANAN_KALENG_DAN_INSTAN/SUPER_BUBUR/Soto_-_sachet.jpeg": "86ac4ea3d826483b9e26f09808cd8a2d",
"assets/assets/products/MIE_INSTAN/INDOMIE/Ayam_Bawang_-_69g.webp": "5f1e226e314c882fef495bcd4ff35c93",
"assets/assets/products/MIE_INSTAN/INDOMIE/Goreng_Aceh_-_90g.jpg": "d8081284180c11af911a142ed8370120",
"assets/assets/products/MIE_INSTAN/INDOMIE/Goreng_Iga_Penyet_-_80g.jpg": "a8c6fd80048641bb15e62ae6214cff6a",
"assets/assets/products/MIE_INSTAN/INDOMIE/Goreng_Jumbo_-_129g.jpg": "4119a335bbce219238163e6ffba9dd64",
"assets/assets/products/MIE_INSTAN/INDOMIE/Goreng_Rendang_-_91g.jpeg": "042c9b4e4fdece3a862c06805fec045e",
"assets/assets/products/MIE_INSTAN/INDOMIE/Hype_Abis_Ayam_Geprek_-_85g.jpeg": "f6fd41963a34335b9a259a843af0de95",
"assets/assets/products/MIE_INSTAN/INDOMIE/indomie_goreng_85gr.png": "260b6c18e870eca250d12686cc72c12e",
"assets/assets/products/MIE_INSTAN/INDOMIE/Kaldu_Ayam_-_75g.jpeg": "ee9a20ef90054fd05d9c2e9bc9adace2",
"assets/assets/products/MIE_INSTAN/INDOMIE/Kari_Ayam_-_72g.jpeg": "ee00f8a5c8bbdd907deb7c7df1a3c9ea",
"assets/assets/products/MIE_INSTAN/INDOMIE/Real_Meat_Rendang_-_pack.jpeg": "6a74e6da21d19ff43a7dd32418022ff8",
"assets/assets/products/MIE_INSTAN/INDOMIE/Seblak_Hot_Jeletot_-_75g.jpg": "97a2515ee7c82deb9b8a42c06ae194fa",
"assets/assets/products/MIE_INSTAN/INDOMIE/Soto_Mie_-_70g.jpeg": "3ae40e58200a3752b0464fe0bd020fa7",
"assets/assets/products/MIE_INSTAN/MIE_GAGA/Mie_100_Extra_Pedas_Goreng_-_85g.jpeg": "a7226200eff373bc0a9e0bdc2b25413f",
"assets/assets/products/MIE_INSTAN/MIE_GAGA/Mie_100_Jalapeno_-_85g.webp": "86d56ff489ad3300f24b4bb4d34755ac",
"assets/assets/products/MIE_INSTAN/MIE_GAGA/Mie_100_Kuah_Pedas_-_75g.webp": "240c0a485fbdd84628930de8ccda5e3c",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/Ayam_Bawang_-_70g.jpeg": "4ffe01e86586440d89679ce845f24afc",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/Cup_Goreng_-_cup.jpeg": "84790c83f14043218a49ebf180e1a9a8",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/Cup_Soto_-_cup.jpeg": "a091e2e0f837884209ec5c32e2f4645a",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/Goreng_Original_-_90g.jpeg": "561bad4d1d6c37592161f332b9053025",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/Kari_Ayam_-_75g.jpeg": "22c2463792ec6e3f3dc4401ab5ffb10f",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/Korean_Spicy_Chicken_-_87g.jpeg": "7cca9ca776273dbbfd420f421744f5ff",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/Korean_Spicy_Soup_-_77g.jpeg": "baf9bba2fa2ddec8c176dc811100a520",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/Soto_-_75g.jpeg": "926fa1ab9406a354631752437a7ccd89",
"assets/assets/products/MIE_INSTAN/MIE_SEDAP/White_Curry_-_81g.jpeg": "38c57bc9eeb1792cd7dc9b470e2adaf3",
"assets/assets/products/MIE_INSTAN/POP_MIE/Ayam_-_cup.jpeg": "cab39e4bd7836b9504097d96719cc447",
"assets/assets/products/MIE_INSTAN/POP_MIE/Baso_-_cup.jpeg": "e91912f17fb5d93ac64bc1b09de0c0a1",
"assets/assets/products/MIE_INSTAN/POP_MIE/Goreng_-_cup.jpeg": "202b872f3ec209cfd08bec284a0f8316",
"assets/assets/products/MIE_INSTAN/POP_MIE/Kari_Ayam_-_cup.jpeg": "773c59db5e1e4ce607daa98ed229cee3",
"assets/assets/products/MIE_INSTAN/POP_MIE/Pedes_Gledek_-_cup.jpeg": "bca9a3c2bdcdf88d5c4f9a34afd50677",
"assets/assets/products/MIE_INSTAN/POP_MIE/Soto_-_cup.jpeg": "adb2fc45d7466482a891391066dbf0ae",
"assets/assets/products/MIE_INSTAN/SARIMI/Goreng_Ayam_Kecap_-_125g.jpeg": "071ba8c7fd00f7994669bad466bd0a5e",
"assets/assets/products/MIE_INSTAN/SARIMI/Isi_2_Ayam_Bawang_-_126g.jpeg": "8f6c7e1f3ed584ef8a40cb53433ab28d",
"assets/assets/products/MIE_INSTAN/SARIMI/Isi_2_Kari_Ayam_-_126g.jpeg": "71af264652ea7cd5095a50c52ab703f6",
"assets/assets/products/MIE_INSTAN/SARIMI/Isi_2_Soto_-_126g.jpeg": "c27aed18acff532646f47979f207dc67",
"assets/assets/products/MIE_INSTAN/SUPERMI/Ayam_Bawang_-_70g.jpeg": "82e52b4bbe8476dfd3f41329a42caa0e",
"assets/assets/products/MIE_INSTAN/SUPERMI/Goreng_-_80g.jpeg": "2db98ed13cf67f1a62af3eec250cee9e",
"assets/assets/products/MIE_INSTAN/SUPERMI/Kaldu_Ayam_-_70g.jpeg": "14a966579b6aeb15459880d6e7f52e39",
"assets/assets/products/MIE_INSTAN/SUPERMI/Nutrimi_-_75g.jpeg": "e12f8621ba3a8b5b2bb0ad9a80461ff2",
"assets/assets/products/MIE_INSTAN/SUPERMI/Soto_-_70g.jpeg": "6a12b05712303a98f4b45a67948f2411",
"assets/assets/products/MINUMAN_SERBUK/BENG_BENG_DRINK/Chocolate_-_sachet.jpeg": "269fe79f424f453d03e3e609145e9ab4",
"assets/assets/products/MINUMAN_SERBUK/CHOCOLATOS/Chocolate_Drink_-_sachet.jpeg": "56567374dab73617ca6cb823b0fe1733",
"assets/assets/products/MINUMAN_SERBUK/CHOCOLATOS/Italian_Chocolate_-_sachet.jpeg": "8fc190aad7b587ee5d655275c9be7e99",
"assets/assets/products/MINUMAN_SERBUK/CHOCOLATOS/Matcha_Latte_-_sachet.jpeg": "84c124e6bc68cd300d7c6484a42cdede",
"assets/assets/products/MINUMAN_SERBUK/JASJUS/Anggur_-_sachet.jpeg": "5b4bcac8954715a7c7e5cc2ed3401a20",
"assets/assets/products/MINUMAN_SERBUK/JASJUS/Jambu_-_sachet.jpeg": "40171eb6759c2bd0192bb37a59c9603c",
"assets/assets/products/MINUMAN_SERBUK/JASJUS/Jeruk_-_sachet.jpeg": "78bfee3a914f5b33a7639334a3b9735b",
"assets/assets/products/MINUMAN_SERBUK/JASJUS/Mangga_-_sachet.jpeg": "19f5a5ab928bf5dfec0f59f0dfcbb8a1",
"assets/assets/products/MINUMAN_SERBUK/JASJUS/Melon_-_sachet.jpeg": "c6d9fe6020ec8ab59c04e117bf4c7de5",
"assets/assets/products/MINUMAN_SERBUK/MARIMAS/Anggur_-_sachet.jpeg": "05f472fd36a839f275080a30ed42a7e4",
"assets/assets/products/MINUMAN_SERBUK/MARIMAS/Jeruk_-_sachet.jpeg": "0e16b9bfb74062b48d682a498df078fd",
"assets/assets/products/MINUMAN_SERBUK/MARIMAS/Mangga_-_sachet.jpeg": "2381f8dc4ca35ccd4f25c58b1d8c95b4",
"assets/assets/products/MINUMAN_SERBUK/MARIMAS/Melon_-_sachet.jpeg": "860382d3bcac83f9956646a991b51578",
"assets/assets/products/MINUMAN_SERBUK/MARIMAS/Sirsak_-_sachet.jpeg": "c4b7aedd39520f821ac1b1b358f68149",
"assets/assets/products/MINUMAN_SERBUK/MARIMAS/Strawberry_-_sachet.jpeg": "e78d500ca6f663172ced1b91cd07f334",
"assets/assets/products/MINUMAN_SERBUK/NUTRISARI/Anggur_-_sachet.jpeg": "0e18b6721e71d9541db5b8189529b9b3",
"assets/assets/products/MINUMAN_SERBUK/NUTRISARI/Blewah_-_sachet.jpeg": "bb993784eaabd8fc2c66b06c822efd0e",
"assets/assets/products/MINUMAN_SERBUK/NUTRISARI/Jeruk_Nipis_-_sachet.jpeg": "b0a27a5514de706f60bb72ff0ecd5983",
"assets/assets/products/MINUMAN_SERBUK/NUTRISARI/Jeruk_Peras_-_sachet.jpeg": "b9d697e82313e4360ecb1d8dff264da9",
"assets/assets/products/MINUMAN_SERBUK/NUTRISARI/Mangga_-_sachet.jpeg": "5bc72f230fee38a09a5e0c796f2515c7",
"assets/assets/products/MINUMAN_SERBUK/NUTRISARI/Sirsak_-_sachet.jpeg": "3afe37098e4632d9efcfcea80cb41538",
"assets/assets/products/MINUMAN_SERBUK/NUTRISARI/Sweet_Orange_-_sachet.jpeg": "beb12553ec7e24b65628183e29a52266",
"assets/assets/products/MINUMAN_SIAP_MINUM/COCA_COLA/Botol_-_390ml.jpeg": "64afb4fc840a244c3e8ca40bc3ed7d76",
"assets/assets/products/MINUMAN_SIAP_MINUM/COCA_COLA/Kaleng_-_250ml.jpeg": "e86e2a72abc6012172532119206937d2",
"assets/assets/products/MINUMAN_SIAP_MINUM/COCA_COLA/Zero_Sugar_-_390ml.jpeg": "bb0588bb62c0a6469156b9446ca6d765",
"assets/assets/products/MINUMAN_SIAP_MINUM/FANTA/Grape_-_390ml.jpeg": "4d11a04a4194fae2be35909a409995c3",
"assets/assets/products/MINUMAN_SIAP_MINUM/FANTA/Kaleng_-_250ml.jpeg": "5ff3ebfb614200f51fc829254cb32019",
"assets/assets/products/MINUMAN_SIAP_MINUM/FANTA/Orange_-_390ml.jpeg": "5815b2ab0c3bb6d9e92fbfd3eeed6f3c",
"assets/assets/products/MINUMAN_SIAP_MINUM/FANTA/Strawberry_-_390ml.jpeg": "476fbef67bc8f7f3e27658915fa79209",
"assets/assets/products/MINUMAN_SIAP_MINUM/FRESTEA/Apple_-_350ml.jpeg": "4f50d0350bf6dc42e148fb90095e3602",
"assets/assets/products/MINUMAN_SIAP_MINUM/FRESTEA/Green_Tea_-_350ml.jpeg": "808f1e5e1152a974db728775b07567bb",
"assets/assets/products/MINUMAN_SIAP_MINUM/FRESTEA/Honey_-_350ml.jpeg": "1001eaafb52da0eabb6ae59105acf571",
"assets/assets/products/MINUMAN_SIAP_MINUM/FRESTEA/Jasmine_-_350ml.jpeg": "7b19a19626fcd54f16824b5d571afce2",
"assets/assets/products/MINUMAN_SIAP_MINUM/KRATINGDAENG/Regular_-_botol.jpeg": "830de3099b6df61395921d0bc86f804f",
"assets/assets/products/MINUMAN_SIAP_MINUM/KRATINGDAENG/Super_-_botol.jpeg": "47421bddd1d992b23075b905eb1fc2ed",
"assets/assets/products/MINUMAN_SIAP_MINUM/MIZONE/Apple_Guava_-_500ml.jpeg": "babc2ba30588ba53d1d8f1a41896071f",
"assets/assets/products/MINUMAN_SIAP_MINUM/MIZONE/Lychee_Lemon_-_500ml.jpeg": "470e48cff79861cb7daa259de16f6e12",
"assets/assets/products/MINUMAN_SIAP_MINUM/MIZONE/Orange_Lime_-_500ml.jpeg": "3c712f28ab79e056d5cd371544963d6d",
"assets/assets/products/MINUMAN_SIAP_MINUM/POCARI_SWEAT/Botol_-_350ml.jpeg": "94dfb164c2e7dc2ec03e13916cce407a",
"assets/assets/products/MINUMAN_SIAP_MINUM/POCARI_SWEAT/Kaleng_-_330ml.jpeg": "3bd2d7feec180ec4196ea0ed71fcf574",
"assets/assets/products/MINUMAN_SIAP_MINUM/SPRITE/Botol_-_390ml.jpg": "8a90c611172f1b2d71de9431d60c0ac4",
"assets/assets/products/MINUMAN_SIAP_MINUM/SPRITE/Kaleng_-_250ml.jpeg": "1c4cd9a44d41869dcaae4a43e0a835a6",
"assets/assets/products/MINUMAN_SIAP_MINUM/SPRITE/Zero_-_390ml.jpeg": "819d6faa5e669913d39cc746d0a05cb7",
"assets/assets/products/MINUMAN_SIAP_MINUM/TEH_BOTOL_SOSRO/-_Less_Sugar_-_350ml.jpeg": "0df869c7fe828c1dad0655a7be13f7e4",
"assets/assets/products/MINUMAN_SIAP_MINUM/TEH_BOTOL_SOSRO/Kotak_-_200m.jpeg": "b77e689fa475ddfa1b6e4c54e567359c",
"assets/assets/products/MINUMAN_SIAP_MINUM/TEH_BOTOL_SOSRO/PET_-_350ml.jpeg": "f2352a2fa0bd562cbaba91b4af116727",
"assets/assets/products/MINUMAN_SIAP_MINUM/TEH_PUCUK_HARUM/Less_Sugar_-_350ml.jpeg": "9605cad7532db22bbabefd4a20007de6",
"assets/assets/products/MINUMAN_SIAP_MINUM/TEH_PUCUK_HARUM/Original_-_350ml.jpeg": "ae6692608e3e3b03945859a48e6b1b58",
"assets/assets/products/MINUMAN_SIAP_MINUM/YOU_C1000/Apple_-_140ml.jpeg": "81ff89106680e35aaa4fcbe75ca8ef8b",
"assets/assets/products/MINUMAN_SIAP_MINUM/YOU_C1000/Lemon_-_140ml.jpeg": "f278961e1d2be930aa1c692420497535",
"assets/assets/products/MINUMAN_SIAP_MINUM/YOU_C1000/Orange_-_140ml.jpeg": "9388292a3464c7aba5e53096c05a8bfe",
"assets/assets/products/MINUMAN_SIAP_MINUM/YOU_C1000/Water_Lemon_-_500ml.jpeg": "2ce3ed1214121f5b671a3a9589f201d2",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/CIPTADENT/Fresh_Mint_-_120g.jpeg": "04ebaf1a1a951d2a8a8d9ccf32396691",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/CIPTADENT/Herbal_-_120g.jpeg": "d421b9535f06a999607077158af74ddc",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/CIPTADENT/Maxi_12_-_120g.png": "d0e217a6ee7907a872c0b072ab941863",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/CLOSE_UP/Menthol_Fresh_-_160g.jpeg": "2ff9bb37ab5d603a42b4de644e0fd952",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/CLOSE_UP/Red_Hot_-_160g.jpeg": "f8d5fa4ec1997459884d2e54553e3860",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/CLOSE_UP/White_Attraction_-_100g.jpeg": "61cf6c35ffd62d1bbe3fae8fd2487c86",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/FORMULA/Formula_Junior_-_pcs.jpeg": "eed94cc748323405d3b1a4dacb2b6358",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/FORMULA/Formula_Sensitive_-_pcs.jpeg": "0d7ac97791cca3d34c2ebda5f87906ca",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/FORMULA/Formula_Strong_Protector_-_pcs.png": "9323b168b6a2e8b35bf5a424cacb6654",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/ORAL_B/Oral-B_Classic_-_pcs.jpeg": "734d465490b87a831a31fad757ae81a9",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/ORAL_B/Oral-B_Complete_-_pcs.jpeg": "3a468e6b0c2e729b5d2c21fc46caf870",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/ORAL_B/Oral-B_Kids_-_pcs.jpeg": "fb5ac6b1d440f446c06021fc627fdabc",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/PEPSODENT/Complete_8_-_120g.jpeg": "4d329f9352fb8cacb080629ff4e5236e",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/PEPSODENT/Herbal_-_120g.jpeg": "1cd40f7cb03d4ca700e0dadb9237cb0a",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/PEPSODENT/Kids_Strawberry_-_50g.jpeg": "b744a7b783d634922e9158ce46208fd9",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/PEPSODENT/Sensitive_Expert_-_100g.jpeg": "d844e3a30c75b5f9a03e6eb60036c4b8",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/PEPSODENT/Sikat_Gigi_Double_Care_-_pcs.jpeg": "455f8fb316ee5d5b3a8cef1e5f56ca02",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/PEPSODENT/Sikat_Gigi_Kids_-_pcs.jpeg": "23023887a1215f21fa24d8a5c42a59c1",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/SENSODYNE/Fresh_Mint_-_100g.jpeg": "d92e973bd4679aaace9004049140ddeb",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/SENSODYNE/Gum_Care_-_100g.png": "8067f8b83fc31036ae27fb7f701709d5",
"assets/assets/products/PASTA_GIGI_DAN_SIKAT_GIGI/SENSODYNE/Repair_&_Protect_-_100g.png": "693165abd4d18bc7ab61ad33ec55c450",
"assets/assets/products/PRODUK_BAYI/JOHNSONS_BABY/Bath_-_200ml.jpeg": "c06a881813fefa97ea97a20d79948fc8",
"assets/assets/products/PRODUK_BAYI/JOHNSONS_BABY/Lotion_-_100m.jpeg": "011eaf28d2269fc5a93736051870d45c",
"assets/assets/products/PRODUK_BAYI/JOHNSONS_BABY/Oil_-_50ml.jpeg": "64dd35f721affb60ace77b205b03b927",
"assets/assets/products/PRODUK_BAYI/JOHNSONS_BABY/Powder_-_100g.jpeg": "1a83e5aaf0a03a5cfbb9ef034922c3c5",
"assets/assets/products/PRODUK_BAYI/JOHNSONS_BABY/Shampoo_-_100ml.jpeg": "7b202f5951ff64fe7da53016fedc7764",
"assets/assets/products/PRODUK_BAYI/MAMYPOKO/Extra_Dry_-_pack.jpeg": "ea8a706791f7f70a2230ddfbadddaa54",
"assets/assets/products/PRODUK_BAYI/MAMYPOKO/Pants_L_-_pack.jpeg": "2bfafe85cda8f4b28d795d49649c309f",
"assets/assets/products/PRODUK_BAYI/MAMYPOKO/Pants_M_-_pack.jpeg": "37e9c941e7f227fd7041d4259679b6ae",
"assets/assets/products/PRODUK_BAYI/MAMYPOKO/Pants_S_-_pack.jpeg": "43ed2b7e1b8efa1e3c7c50bac800460c",
"assets/assets/products/PRODUK_BAYI/MAMYPOKO/Pants_XL_-_pack.jpeg": "830307854fcf78c9333f2895df8e1698",
"assets/assets/products/PRODUK_BAYI/MAMYPOKO/Tape_Newborn_-_pack.jpeg": "d26a9543a35a7d2290d9dbf362101c3a",
"assets/assets/products/PRODUK_BAYI/MERRIES/Pants_L_-_pack.jpeg": "c472753ece95489d3263ab7d414ed7dc",
"assets/assets/products/PRODUK_BAYI/MERRIES/Pants_M_-_pack.jpeg": "c93e62ca3bd5094c245374991490ff81",
"assets/assets/products/PRODUK_BAYI/MERRIES/Pants_S_-_pack.jpeg": "2f7789b7f0dc3adde1abae474746d1fa",
"assets/assets/products/PRODUK_BAYI/MERRIES/Pants_XL_-_pack.jpeg": "5ae02d65d24915160690347305e3a997",
"assets/assets/products/PRODUK_BAYI/MERRIES/Tape_Newborn_-_pack.jpeg": "246438b153aa751dc1f36b210d83ea50",
"assets/assets/products/PRODUK_BAYI/MERRIES/Tape_S_-_pack.jpeg": "8bbb2fa570779f7416ae69199b3b44c7",
"assets/assets/products/PRODUK_BAYI/MILNA/Milna_Biskuit_Bayi_Original_-_box.jpeg": "1b61cfcc65b534a7199187888f6d38b2",
"assets/assets/products/PRODUK_BAYI/MILNA/Milna_Bubur_Ayam_Bayam_-_box.jpeg": "59ed832bb587e70093270a84774c5fb9",
"assets/assets/products/PRODUK_BAYI/PROMINA/Promina_Biskuit_Bayi_-_box.jpeg": "fd59256f82fe06396bbdaf2aff7fafa6",
"assets/assets/products/PRODUK_BAYI/PROMINA/Promina_Bubur_Tim_Ayam_Kampung_-_box.jpeg": "8c5ecb30609dbdf345f27a8672cddd09",
"assets/assets/products/PRODUK_BAYI/PROMINA/Promina_Puffs_-_pack.jpeg": "25e843f701f730856cb44e55579cff5b",
"assets/assets/products/PRODUK_BAYI/SWEETY/Gold_Pants_L_-_pack.jpeg": "7adc39808954da3fb05ec68058994db9",
"assets/assets/products/PRODUK_BAYI/SWEETY/Gold_Pants_M-_pack.jpeg": "2f2f2db7150f983ce32f6459001b0170",
"assets/assets/products/PRODUK_BAYI/SWEETY/Gold_Pants_S_pack.jpeg": "55879ecce20e628ff00ead45e371c531",
"assets/assets/products/PRODUK_BAYI/SWEETY/Gold_Pants_XL_-_pack.jpeg": "cf44d9ce6dbf816cb2455b0c30f96b47",
"assets/assets/products/PRODUK_BAYI/SWEETY/Silver_Pants_L_-_pack.jpeg": "afe0efe2c87539c689ace2aa1d7402c4",
"assets/assets/products/PRODUK_BAYI/SWEETY/Silver_Pants_M_-_pack.jpeg": "5484e28cad8c220a016da99f3bfdec67",
"assets/assets/products/PRODUK_BAYI/SWEETY/Silver_Pants_S_-_pack.jpeg": "98e2118fd3719b3250b72a80c96221a7",
"assets/assets/products/PRODUK_BAYI/SWEETY/Silver_Pants_XL_-_pack.jpeg": "b79c5f49dc016a40ee53c224768a86a0",
"assets/assets/products/PRODUK_BAYI/ZWITSAL/Baby_Bath_-_200ml.jpeg": "b4d8a49429335191273d21cc9f6784f5",
"assets/assets/products/PRODUK_BAYI/ZWITSAL/Baby_Cologne_-_100ml.jpeg": "4a0576537eade917bfb5da0342b38957",
"assets/assets/products/PRODUK_BAYI/ZWITSAL/Baby_Oil_-_100ml.jpeg": "e08866f76394bf99e74167d130de597a",
"assets/assets/products/PRODUK_BAYI/ZWITSAL/Baby_Powder_-_300g.jpeg": "393a498e9de52bb67a8de9943a6cc6e6",
"assets/assets/products/PRODUK_BAYI/ZWITSAL/Baby_Shampoo_-_100ml.jpeg": "25b9561d730aafb3c12c9d441d28b7fc",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/CLEAR/Anti_Ketombe_-_sachet.jpeg": "d2f1b35f8c6b6042b244dbf5820a3947",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/CLEAR/Hijab_Pure_-_botol.jpeg": "2086f8e533bd563383d08d9d4c3aa98d",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/CLEAR/Men_Cool_Sport_-_340ml.jpeg": "5d8683cd6e88ad9873c6a65995e046a4",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/CLEAR/Men_Ice_Cool_Menthol_-_340ml.jpeg": "b6aa6151cc3955bec43df3a6399a6aea",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/DETTOL/Cool_-_cair.jpeg": "4957d630b1f9c2393635d9f58654a9d1",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/DETTOL/Original_-_cair.jpeg": "d3715c62eedb567e3b99018abf256dc8",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/DETTOL/Sensitive_-_cair.jpeg": "4a36a4b9b9bbac21e146ab6a15f4fa24",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/DETTOL/Skincare_-_cair.jpeg": "f51c85e76e5f8bfb1e50143679cefd91",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/DOVE/Deeply_Nourishing_-_cair.jpeg": "ba65ad60bb29b2700cf72be201e14f8e",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/DOVE/Go_Fresh_-_cair.jpeg": "9cc4b92606b6ed26ae8bcd0e46f39c4a",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/DOVE/Sensitive_Skin_-_cair.jpeg": "9f60a0646f2a87b003bde2433f0e27d3",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/DOVE/White_Beauty_Bar_-_batang.jpeg": "6c01d6ce0593eff23a702cd5cb62d921",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/LIFEBUOY/Cool_Fresh_-_cair.jpeg": "a09526a86606562e890e2e133fc65711",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/LIFEBUOY/Lemon_Fresh_-_cair.jpeg": "f09257ae593e3c895917d7595d5449ba",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/LIFEBUOY/Mild_Care_-_cair.jpeg": "dd967a9ee5d20afb15b5212a6d5294d1",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/LIFEBUOY/Total_10_-_cair.jpeg": "e4cdac244f528911d3cd9c288f8a6ab2",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/LUX/Botanicals_-_cair.jpeg": "1ad107853e7966b5af4788dc179ac6f8",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/LUX/Magical_Spell_-_cair.jpeg": "dd978d4742727a99b43a3ea4ff4dc372",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/LUX/Soft_Rose_-_cair.jpeg": "d13678e961155b50241acd19b841ea4e",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/LUX/White_Impress_-_cair.jpeg": "5b023302d5f8a901f5b2faab034fdc01",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/PANTENE/Anti_Lepek_-_botol.jpeg": "0956407bddfd6af1dfd22615e3da8926",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/PANTENE/Hair_Fall_Control_-_botol.jpeg": "6c1c6d1eafaa14fc550ff61b3f047b63",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/PANTENE/Smooth_&_Silky_-_botol.jpeg": "136275417ca49fdc8ee54938c1619227",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/PANTENE/Total_Damage_Care_-_botol.jpeg": "05f13aeddb965da0c1a4a2886e27587d",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/SUNSILK/Black_Shine_-_botol.jpeg": "2027af9a8c4dd50a374f37919a962060",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/SUNSILK/Hair_Fall_Solution_-_botol.jpeg": "a72ad7d5e61b47f849beefccf80c3dc9",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/SUNSILK/Hijab_Recharge_-_botol.jpeg": "7b540eada8769fe517e25162311ab2df",
"assets/assets/products/SABUN_SHAMPOO_DAN_PERSONAL_CARE/SUNSILK/Soft_&_Smooth_-_botol.jpeg": "26d6ee8d5c7efdcb7142025fd21ce970",
"assets/assets/products/SEMBAKO/BERAS/Pandan_Wangi_-_5kg.jpeg": "d25e8b2f02fdf43cd800c3dc071cf3d6",
"assets/assets/products/SEMBAKO/BERAS/Ramos_-_25kg.jpeg": "5803c2bd27d1a47a1d1555ddf120995f",
"assets/assets/products/SEMBAKO/BERAS/Sania_Premium_-_5kg.webp": "03e8700121bc616e4386b431be60e85c",
"assets/assets/products/SEMBAKO/BERAS/Topi_Koki_Premium_-_5kg.jpeg": "2c5d4ef132b5a4201444f8ba42aafe87",
"assets/assets/products/SEMBAKO/GARAM_DAN_MARGARIN/Blue_Band_-_250g.jpeg": "2bdc9b13ea9275aeb590b4079d59a3b7",
"assets/assets/products/SEMBAKO/GARAM_DAN_MARGARIN/Dolphin_Garam_Halus_-_500g.jpeg": "fc4bf98858d634c799e85fbbc7ccf676",
"assets/assets/products/SEMBAKO/GARAM_DAN_MARGARIN/ForVita_-_200g.jpeg": "00c4eedb984c0298bb56421779627e8e",
"assets/assets/products/SEMBAKO/GARAM_DAN_MARGARIN/Palmia_-_200g.jpeg": "685a057b6ce61edd55eea55a140638be",
"assets/assets/products/SEMBAKO/GARAM_DAN_MARGARIN/Refina_Garam_Meja_-_500g.jpeg": "9056c5f1226782e0f3315aecd81f387c",
"assets/assets/products/SEMBAKO/GULA/Gulaku_Hijau_-_1kg.jpeg": "6accedba8d262cc53508f5e01aa3e5c6",
"assets/assets/products/SEMBAKO/GULA/Gulaku_Kuning_-_1kg.jpeg": "c9bc7ff9f7539fd34111cebbe8b4fab9",
"assets/assets/products/SEMBAKO/GULA/Gula_Pasir_Curah_-_500g.jpg": "a8ffcb23ac967610d8cf8a638362d57d",
"assets/assets/products/SEMBAKO/GULA/Rose_Brand_Gula_Pasir_-_1kg.jpeg": "7f3df27bd5a82ad48bc8c7b4e7c10f83",
"assets/assets/products/SEMBAKO/MINYAK_GORENG/Bimoli_Botol_-_2L.webp": "4ff060a52935eb37890e7032659e6916",
"assets/assets/products/SEMBAKO/MINYAK_GORENG/Bimoli_Refill_-_2L.jpeg": "eeaba830e3897bcc39b7f6356b906b46",
"assets/assets/products/SEMBAKO/MINYAK_GORENG/Filma_-_1L.webp": "11261ad6f3cf61c0cad702f6c042e6f7",
"assets/assets/products/SEMBAKO/MINYAK_GORENG/Fortune_Refill_-_2L.jpeg": "6051b72515088cce7ecbf70026ded134",
"assets/assets/products/SEMBAKO/MINYAK_GORENG/Sania_-_1L.jpg": "ecd09f3d032ab3a22c87b1f96464cd55",
"assets/assets/products/SEMBAKO/MINYAK_GORENG/Tropical_Botol_-_1L.jpeg": "da5ae209573d66f1a07153d2b08b21d2",
"assets/assets/products/SEMBAKO/MINYAK_GORENG/Tropical_Refill_-_1L.jpeg": "043743ac74cb330a6aede64a87cb3232",
"assets/assets/products/SEMBAKO/TEPUNG/Cakra_Kembar_-_1kg.jpeg": "e72c87e8a013e9345e9f4c60a44a154a",
"assets/assets/products/SEMBAKO/TEPUNG/Kunci_Biru_-_1kg.jpeg": "fd56a9e89e5031ca19de2afc29694206",
"assets/assets/products/SEMBAKO/TEPUNG/Rose_Brand_Tapioka_-_500g.jpeg": "293d340407b5ad8c2ace711ae047fde7",
"assets/assets/products/SEMBAKO/TEPUNG/Rose_Brand_Tepung_Beras_-_500g.jpeg": "d5c1026766ffb9aa0c2a5b9c1c3cf7c5",
"assets/assets/products/SEMBAKO/TEPUNG/Rose_Brand_Tepung_Ketan_-_500g.jpeg": "09c6d005cfdcc4c995486f5ffe798624",
"assets/assets/products/SEMBAKO/TEPUNG/Segitiga_Biru_-_1kg.jpg": "57a438414867396e2d2926b85f4b274c",
"assets/assets/products/SNACK_DAN_BISQUIT/CHITATO/Ayam_Bumbu_-_35g.jpeg": "4c27857c56dd175af1ad91ef58d3de7a",
"assets/assets/products/SNACK_DAN_BISQUIT/CHITATO/Keju_Supreme_-_35g.jpeg": "0fe16d3d050642f3548bf9a3c5a1397c",
"assets/assets/products/SNACK_DAN_BISQUIT/CHITATO/Lite_Rumput_Laut_-_35g.jpeg": "257301e44d481df652af09ee45802447",
"assets/assets/products/SNACK_DAN_BISQUIT/CHITATO/Sapi_Panggang_-_35g.jpeg": "00f9366c1d15a2f5fa52eaa6f3551e2c",
"assets/assets/products/SNACK_DAN_BISQUIT/KHONG_GUAN/Assorted_Biscuits_-_kaleng.jpeg": "47347b12467af9bcef8b46104b46a77f",
"assets/assets/products/SNACK_DAN_BISQUIT/KHONG_GUAN/Malkist_-_pack.jpeg": "2c43bd285899c36a8c07c51494ac5d8a",
"assets/assets/products/SNACK_DAN_BISQUIT/KHONG_GUAN/Red_Assorted_-_kaleng.jpeg": "fc3c8e937bb6cac9f7de34a3152e20a4",
"assets/assets/products/SNACK_DAN_BISQUIT/KHONG_GUAN/Saltcheese_-_pack.jpeg": "db0f41dd3382eeb002a5e891e64cdd07",
"assets/assets/products/SNACK_DAN_BISQUIT/NABATI/Richeese_-_pack.jpeg": "26c4bfdf1ddc7f212cb87c017ef63ba2",
"assets/assets/products/SNACK_DAN_BISQUIT/NABATI/Richoco_-_pack.jpeg": "78f76019ece9cdc532b4bfc4914f4497",
"assets/assets/products/SNACK_DAN_BISQUIT/NABATI/Wafer_Coklat_-_50g.jpeg": "8e5d8bb83a4ca4373d3cce996f366e71",
"assets/assets/products/SNACK_DAN_BISQUIT/NABATI/Wafer_Keju_-_50g.jpeg": "67303fb67d0b85cf711e6259b097914e",
"assets/assets/products/SNACK_DAN_BISQUIT/OREO/Chocolate_Creme_-_pack.jpeg": "eedd872576f28ff647087bf0f106c159",
"assets/assets/products/SNACK_DAN_BISQUIT/OREO/Double_Stuff_-_pack.jpeg": "2e5fdbde5757051dcd4acde52142915f",
"assets/assets/products/SNACK_DAN_BISQUIT/OREO/Mini_-_cup.jpeg": "6c8731fa4ac39496ea4ca959940e30d6",
"assets/assets/products/SNACK_DAN_BISQUIT/OREO/Original_-_pack.jpeg": "d259df1bc7197e285a0d8d87a96113ca",
"assets/assets/products/SNACK_DAN_BISQUIT/OREO/Strawberry_Creme_-_pac.jpeg": "cbbcfd2755ff9c54a4ebe3a1bcd4620e",
"assets/assets/products/SNACK_DAN_BISQUIT/PIATTOS/Rumput_Laut_-_68g.jpeg": "35929fc4a1c8d351b5540145b3866f87",
"assets/assets/products/SNACK_DAN_BISQUIT/PIATTOS/Sambal_Geprek_-_68g.jpeg": "16648625adf84b66415742eb08a1f715",
"assets/assets/products/SNACK_DAN_BISQUIT/PIATTOS/Sapi_Panggang_-_68g.jpeg": "beb1769c5828ca4c59fedd2f02eb671e",
"assets/assets/products/SNACK_DAN_BISQUIT/QTELA/Singkong_Balado_-_60g.jpeg": "1e7af6c09713534b981713eae8023b56",
"assets/assets/products/SNACK_DAN_BISQUIT/QTELA/Singkong_BBQ_-_60g.jpeg": "c4624ffedf46137a120defd8dacdcf2d",
"assets/assets/products/SNACK_DAN_BISQUIT/QTELA/Singkong_Original_-_60g.jpeg": "8c0f944a466c4a677ac6f401df876b11",
"assets/assets/products/SNACK_DAN_BISQUIT/QTELA/Tempe_-_55g.jpeg": "640a49684ceea9f1246afd92e7b4c3f2",
"assets/assets/products/SNACK_DAN_BISQUIT/ROMA/Kelapa_-_pack.jpeg": "ea3508ed95e19abae7ab763dbc8602eb",
"assets/assets/products/SNACK_DAN_BISQUIT/ROMA/Malkist_Abon_-_pack.jpeg": "41b8dcdd5a15a63e22f8b82b314e4082",
"assets/assets/products/SNACK_DAN_BISQUIT/ROMA/Malkist_Coklat_-_pack.jpeg": "d74c37c52ab1b7c6423186d1db393786",
"assets/assets/products/SNACK_DAN_BISQUIT/ROMA/Sari_Gandum_-_pack.jpeg": "29d32267cb3b88f8bf1c3c21d9daa84f",
"assets/assets/products/SNACK_DAN_BISQUIT/ROMA/Slai_Olai_Blueberry_-_pack.jpeg": "df88c79d17ade606a98855288b595320",
"assets/assets/products/SNACK_DAN_BISQUIT/ROMA/Slai_Olai_Strawberry_-_pack.jpeg": "832dd2479acbb5669c1f1cf8a91586ac",
"assets/assets/products/SNACK_DAN_BISQUIT/TARO/Net_BBQ_-_36g.jpeg": "5e3c5a3791f1af35c36ee72c6fe2ba1d",
"assets/assets/products/SNACK_DAN_BISQUIT/TARO/Net_Seaweed_-_36g.jpeg": "5d9c3a8a4d741fbbdf99b290aa7102f8",
"assets/assets/products/SNACK_DAN_BISQUIT/TARO/Potato_BBQ_-_40g.jpeg": "001da17cf66853ea3677b6a7fa70fb08",
"assets/assets/products/SNACK_DAN_BISQUIT/TARO/Stick_-_40g.jpeg": "52bf90952681b210b8dedb56142f5327",
"assets/assets/products/SUSU/BEAR_BRAND/Gold_Malt_-_kaleng.jpeg": "316b85d3b168cdf1068e899766ca0085",
"assets/assets/products/SUSU/BEAR_BRAND/Gold_White_Tea_-_kaleng.jpeg": "efead926c7dfb412a6eae9e9a1856cd6",
"assets/assets/products/SUSU/BEAR_BRAND/Original_-_kaleng_189ml.jpeg": "6f61fc6e61df94f493ee3e78bf54c994",
"assets/assets/products/SUSU/DANCOW/1+_-_400g.jpeg": "65b15cd031de1438c2042266ce6b2330",
"assets/assets/products/SUSU/DANCOW/3+_-_400g.jpeg": "35331b886b30964473a5ef2737f424b5",
"assets/assets/products/SUSU/DANCOW/5+_-_400g.jpeg": "115a44e3786c0102731f30f4aea60d10",
"assets/assets/products/SUSU/DANCOW/Fortigro_Coklat_-_200g.jpeg": "e93e71f7a077964b31472f08e1f59546",
"assets/assets/products/SUSU/DANCOW/Fortigro_Full_Cream_-_400g.jpeg": "0ca404ca721a553f74155f193d66e8e5",
"assets/assets/products/SUSU/FRISIAN_FLAG/Kental_Manis_Coklat_-_kaleng.jpeg": "4848360ae0f76be95fd3c1216dea13fe",
"assets/assets/products/SUSU/FRISIAN_FLAG/Kental_Manis_Putih_-_kaleng.jpeg": "0e35e32ac30f3faf6c2f7b4eabb14d46",
"assets/assets/products/SUSU/FRISIAN_FLAG/UHT_Coklat_-_225ml.jpeg": "7892555efa3a39094ce10f5b9323cd5d",
"assets/assets/products/SUSU/FRISIAN_FLAG/UHT_Full_Cream_-_225ml.jpeg": "9c8ed7979a6afc04ccaba0533c800ac2",
"assets/assets/products/SUSU/FRISIAN_FLAG/UHT_Strawberry_-_225ml.jpeg": "355edbcd43fdd53ce53210b8e7b0c60a",
"assets/assets/products/SUSU/INDOMILK/Kental_Manis_-_kaleng.jpeg": "cd9db47a72607753564bd4a89ad71f70",
"assets/assets/products/SUSU/INDOMILK/Kental_Manis_-_sachet.jpeg": "7ccb42f38872cdae92ea72667284fc1d",
"assets/assets/products/SUSU/INDOMILK/UHT_Coklat_-_190ml.jpeg": "8b84449f106c0c017e0767c9519d7b54",
"assets/assets/products/SUSU/INDOMILK/UHT_Full_Cream_-_190ml.jpeg": "54436488c001f63e33910432d23eb024",
"assets/assets/products/SUSU/INDOMILK/UHT_Strawberry_-_190ml.jpeg": "191640f040416683a611440108aeccde",
"assets/assets/products/SUSU/MILO/3_in_1_-_sachet.jpeg": "855f0825d1fe19c91ccc2502bf2a5ef5",
"assets/assets/products/SUSU/MILO/Activ-Go_-_600g.jpeg": "a39841a90bf286b389bb9162c0476418",
"assets/assets/products/SUSU/MILO/Sachet_-_22g.jpeg": "c58429566bdd2dec14133e27ff282540",
"assets/assets/products/SUSU/MILO/UHT_-_180ml.jpeg": "e1fc70820781c3d46c93af978c012bec",
"assets/assets/products/SUSU/SGM/Ananda_-_400g.jpeg": "b75aa5a326c5463ae61d7caee78b3c06",
"assets/assets/products/SUSU/SGM/Eksplor_1+_-_400g.jpeg": "86de38ba32979567e9b32829b7357f28",
"assets/assets/products/SUSU/SGM/Eksplor_3+_-_400g.jpeg": "62440e2aa4d41f55f54cead8d434cbe8",
"assets/assets/products/SUSU/SGM/Eksplor_5+_-_400g.jpeg": "2215b597767568eb77c0a70a8f995cb0",
"assets/assets/products/SUSU/ULTRAMILK/Coklat_-_1L.jpeg": "ae17a73a3a06806485cbb5abee54e298",
"assets/assets/products/SUSU/ULTRAMILK/Full_Cream_-_125ml.jpeg": "a35fb7010e31c21b30d46345c399e661",
"assets/assets/products/SUSU/ULTRAMILK/Low_Fat_-_1L.jpeg": "16fad5f079f52f2f8a47feb9118012fc",
"assets/assets/products/SUSU/ULTRAMILK/Strawberry_-_200ml.jpeg": "facf464055dfb329810d27571edce9ea",
"assets/assets/Qtela%2520Tempe%2520Original%252055g.jpg": "070610d963cb9a591dc53bab8d4c3e86",
"assets/assets/Sambal%2520Indofood%2520Extra%2520Pedas%2520275ml.jpg": "8f6729537bb20b5e989ee2f1ffe53e50",
"assets/assets/Sambal%2520Indofood%2520Pedas%2520Manis%2520275ml.jpg": "fc807bf80e399ac7a20ac4933be94f15",
"assets/assets/Sarimi%2520Isi%25202%2520Goreng.jpg": "1b42f939beccd88a848f44efe1e4b535",
"assets/assets/sea.jpg": "63d4bf65869ad882227419e3c5a04f0e",
"assets/assets/Simas%2520Palmia%2520Margarin%2520200g.jpg": "bbaf8172e709d9a52055579cff052459",
"assets/assets/Tekita%2520Teh%2520Tarik%2520350ml.jpg": "482e0e21be9cb1319a221f5edf323cea",
"assets/assets/Tepung%2520Terigu%2520Cakra%2520Kembar%25201kg.jpg": "e72c87e8a013e9345e9f4c60a44a154a",
"assets/assets/Tepung%2520Terigu%2520Kunci%2520Biru%25201kg.jpg": "9f3b332250bf6b715aa98ed09c6f8ad6",
"assets/assets/Tepung%2520Terigu%2520Segitiga%2520Biru%25201kg.jpg": "a520b4cfc13b77f52e7047c1846e9ce1",
"assets/assets/Tissue%2520Paseo%2520250%2520Sheets.jpg": "e25230c074beb519e5a4d650d4436f8d",
"assets/assets/Tissue%2520Paseo%2520Travel%2520Pack.jpg": "4cd08fd30631c38206f9256d230b38f2",
"assets/assets/Trenz%2520Truffle%2520100g.jpg": "870b13a68886ff4128c51280d7e0e185",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "5bf80ade4473f9d115f2629f04bdcdf4",
"assets/NOTICES": "59ea53b3a1f40c47b8646dd042cf67a1",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "4e132c26326f68a64c70efe28c858ae4",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "58a2d1f1b1b010c661632b5e7863ce3e",
"/": "58a2d1f1b1b010c661632b5e7863ce3e",
"main.dart.js": "5e3e645fb6bceda9b2a9f0cf31d57520",
"manifest.json": "bc10bc3626769f11395cc35b1d872a87",
"version.json": "e59a537ffe26cc90c758b62492057514"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
