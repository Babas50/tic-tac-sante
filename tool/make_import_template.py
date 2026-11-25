"""Génère assets/import/modele-tic-tac-sante.xlsx, le modèle d'import.

Usage : python3 tool/make_import_template.py   (nécessite openpyxl)

Les lignes d'exemple doivent rester identiques à `templateExamples` dans
lib/core/med_import.dart (l'appli les ignore si elles sont laissées).
"""
import os
from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.worksheet.datavalidation import DataValidation

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "import", "modele-tic-tac-sante.xlsx")

HEADS = ["Médicament *", "Description", "Consigne", "Heures de prise", "Quantité", "Unité", "Fréquence"]
WIDTHS = [24, 26, 36, 22, 11, 14, 22]
EXAMPLES = [
    ("Doliprane 1000 mg", "Paracétamol, douleur", "3 maximum par jour, espacer de 6 heures", "08:00 ; 14:00 ; 20:00", 1.5, "comprimé", "Tous les jours"),
    ("Kardégic 75", "Aspirine, cœur", "Pendant le repas", "12:30", 1, "sachet", "Tous les jours"),
    ("Collyre", "Yeux secs", "", "19:00", 1, "goutte", "Tous les jours"),
    ("Vitamine D", "", "Pendant un repas", "09:00", 1, "dose", "Lundi"),
    ("Furosémide 40 mg", "Diurétique", "Le matin", "08:00", 1, "comprimé", "1 jour sur 2"),
    ("Spray nasal", "", "Si besoin", "", None, "", ""),
]
UNITS = ["comprimé", "gélule", "sachet", "goutte", "ml", "cuillère", "bouffée", "dose", "injection", "patch", "application"]
GUIDE = [
    ("Médicament", "Oui", "Le nom tel qu’il doit apparaître dans l’appli.", "Doliprane 1000 mg"),
    ("Description", "Non", "À quoi il sert, molécule… Visible dans la fiche du médicament.", "Paracétamol, douleur"),
    ("Consigne", "Non", "Rappelée au moment de la prise.", "3 maximum par jour"),
    ("Heures de prise", "Non", "Une ou plusieurs heures séparées par « ; ». Vide = pas de rappel : le médicament est seulement ajouté à la liste.", "08:00 ; 20:00  ou  8h ; 20h"),
    ("Quantité", "Non", "Par prise. Un chiffre, virgule acceptée. Vide = 1.", "1  /  0,5  /  1,5  /  2"),
    ("Unité", "Non", "Choisir dans la liste ou écrire la vôtre. Vide = comprimé.", "comprimé, gélule, goutte"),
    ("Fréquence", "Non", "« Tous les jours » (si vide), « 1 jour sur N », ou des jours de la semaine séparés par des virgules.", "1 jour sur 2  ou  Lundi, Jeudi"),
]
NOTES = [
    "Les lignes 2 à 7 de l’onglet « Mes médicaments » sont des exemples : remplacez-les ou supprimez-les (laissées telles quelles, elles sont ignorées).",
    "Même médicament avec des quantités différentes selon l’heure : faites deux lignes avec le même nom.",
    "Liste dans Word : sélectionnez le tableau, copiez, puis collez dans « Mes médicaments » en case A2, colonnes dans le même ordre.",
    "Ne changez pas les titres de la ligne 1. Enregistrez au format .xlsx (ou CSV), puis importez le fichier depuis l’appli : Médicaments, Importer.",
]

BRAND = PatternFill("solid", fgColor="0D5C63")
THIN = Side(style="thin", color="D3DFDE")

wb = Workbook()
ws = wb.active
ws.title = "Mes médicaments"
for i, (h, w) in enumerate(zip(HEADS, WIDTHS), 1):
    c = ws.cell(1, i, h)
    c.font = Font(bold=True, color="FFFFFF")
    c.fill = BRAND
    c.alignment = Alignment(vertical="center")
    c.comment = Comment(GUIDE[i - 1][2], "Tic-Tac Santé")
    ws.column_dimensions[chr(64 + i)].width = w
ws.row_dimensions[1].height = 24
for r, ex in enumerate(EXAMPLES, 2):
    for c, v in enumerate(ex, 1):
        if v not in ("", None):
            ws.cell(r, c, v)
for r in range(2, 301):
    ws.cell(r, 4).number_format = "@"  # heures gardées en texte
    ws.cell(r, 7).number_format = "@"
ws.freeze_panes = "A2"
dv = DataValidation(type="list", formula1='"' + ",".join(UNITS) + '"', allow_blank=True, showErrorMessage=False)
dv.add("F2:F300")
ws.add_data_validation(dv)
dv2 = DataValidation(type="list", formula1='"Tous les jours,1 jour sur 2,1 jour sur 3,1 jour sur 7"', allow_blank=True, showErrorMessage=False)
dv2.add("G2:G300")
ws.add_data_validation(dv2)

g = wb.create_sheet("Mode d’emploi")
g["A1"] = "Tic-Tac Santé : importer vos médicaments"
g["A1"].font = Font(bold=True, size=14, color="0D5C63")
g["A2"] = "Remplissez l’onglet « Mes médicaments », une ligne par médicament."
for i, h in enumerate(["Colonne", "Obligatoire", "Ce qu’il faut écrire", "Exemples"], 1):
    c = g.cell(4, i, h)
    c.font = Font(bold=True, color="FFFFFF")
    c.fill = BRAND
for r, row in enumerate(GUIDE, 5):
    for i, v in enumerate(row, 1):
        c = g.cell(r, i, v)
        c.alignment = Alignment(wrap_text=True, vertical="top")
        c.border = Border(top=THIN, bottom=THIN, left=THIN, right=THIN)
    g.cell(r, 1).font = Font(bold=True)
for col, w in zip("ABCD", [18, 12, 70, 32]):
    g.column_dimensions[col].width = w
for i, n in enumerate(NOTES, 13):
    g.cell(i, 1, "• " + n)

wb.save(OUT)
print("écrit :", os.path.normpath(OUT))
