"""Generate docs/api_design_report.pdf for the Week-3 REST API assignment."""

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

TITLE = 'MoMo SMS Processing System — REST API Report'
OUT = 'docs/api_design_report.pdf'

styles = getSampleStyleSheet()
h1 = ParagraphStyle('H1x', parent=styles['Heading1'], fontSize=15, spaceAfter=8)
h2 = ParagraphStyle('H2x', parent=styles['Heading2'], fontSize=12.5, spaceBefore=10, spaceAfter=5)
body = ParagraphStyle('BodyX', parent=styles['BodyText'], fontSize=9.5, leading=13)
mono = ParagraphStyle('MonoX', parent=styles['Code'], fontSize=8.5, leading=11)


def build():
    doc = SimpleDocTemplate(OUT, pagesize=A4,
                            leftMargin=18*mm, rightMargin=18*mm,
                            topMargin=16*mm, bottomMargin=16*mm,
                            title=TITLE, author='MoMo Data Processing Team')
    story = []
    story.append(Paragraph(TITLE, h1))

    story.append(Paragraph('1. Introduction to API security', h2))
    story.append(Paragraph(
        'The MoMo SMS processing system stores 1,691 mobile-money SMS records. '
        'Exposing that data to mobile and web clients requires an API that is easy '
        'to use but still protected. This API uses HTTP Basic Authentication: every '
        'request must carry an Authorization header with a valid username and '
        'password. Requests with missing or wrong credentials are rejected with a '
        '401 Unauthorized response, so no transaction data can be read or changed '
        'without logging in first. The API is built with plain Python (http.server) '
        'and stores transactions in memory.', body))

    story.append(Paragraph('2. API endpoints', h2))
    endpoint_rows = [
        ['Method', 'Endpoint', 'Purpose', 'Success', 'Errors'],
        ['GET', '/transactions', 'List all SMS transactions', '200 JSON array', '401'],
        ['GET', '/transactions/{id}', 'View one transaction', '200 JSON object', '401, 404'],
        ['POST', '/transactions', 'Add a new transaction', '201 new record', '400, 401'],
        ['PUT', '/transactions/{id}', 'Update an existing record', '200 updated record', '400, 401, 404'],
        ['DELETE', '/transactions/{id}', 'Delete a record', '200 removed record', '401, 404'],
    ]
    table = Table(endpoint_rows, colWidths=[16*mm, 38*mm, 52*mm, 40*mm, 28*mm])
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1a237e')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#90a4ae')),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#eceff1')]),
    ]))
    story.append(table)
    story.append(Paragraph(
        'Example request and response (GET /transactions/1):', body))
    story.append(Paragraph(
        '$ curl -u admin:Maureen123! http://127.0.0.1:8000/transactions/1<br/>'
        '{"id": 1, "address": "M-Money", "body": "You have received 2000 RWF from Jane Smith ...", '
        '"amount": 2000.0}', mono))
    story.append(Paragraph(
        'Error codes: 400 = invalid JSON body, 401 = missing/wrong credentials, '
        '404 = unknown id or route.', body))

    story.append(Paragraph('3. DSA comparison — linear search vs dictionary lookup', h2))
    story.append(Paragraph(
        'Both methods find a transaction by id over the parsed data set. '
        'The test searched 20 random record ids, repeated over several runs, and '
        'averaged the totals:', body))
    dsa_rows = [
        ['Method', 'Total time (average)', 'Complexity'],
        ['Linear search (scan the list)', '0.000646 s', 'O(N)'],
        ['Dictionary lookup (by_id[id])', '0.000003 s', 'O(1)'],
    ]
    dtable = Table(dsa_rows, colWidths=[58*mm, 60*mm, 55*mm])
    dtable.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1a237e')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8.5),
        ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#90a4ae')),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#eceff1')]),
    ]))
    story.append(dtable)
    story.append(Paragraph(
        'The dictionary lookup is about 195x faster in this test '
        '(dataset size: 1,691 records).', body))
    story.append(Paragraph(
        'Why is dictionary lookup faster? A dictionary stores each value at a slot '
        'computed from a hash of its key, so a lookup jumps straight to the value in '
        'O(1) time. Linear search compares every element from the start, so in the '
        'worst case it scans all N records — O(N) time. The difference grows as more '
        'records are added.', body))
    story.append(Paragraph(
        'Suggested alternative: sort the records by id and use binary search, which '
        'finds an id in O(log N) comparisons. It is still slower than a dictionary for '
        'a single lookup but uses a plain list and keeps records ordered; a good '
        'choice when memory is limited or the list is static.', body))

    story.append(Paragraph('4. Reflection — limitations of Basic Auth', h2))
    story.append(Paragraph(
        'Basic Authentication sends a username and password as Base64 text in every '
        'request header. Base64 is encoding, not encryption — anyone who intercepts '
        'the traffic can decode the password, unless the whole exchange runs over '
        'HTTPS. It also has no expiry: the credential stays valid until changed, and '
        'it cannot be scoped, so one leaked password exposes every endpoint.', body))
    story.append(Paragraph(
        'Stronger alternatives: JWT (JSON Web Tokens) — a signed, expiring token '
        'issued after login, so passwords are not repeated on every request and '
        'tokens can be revoked; and OAuth2 — delegated access with scopes and refresh '
        'tokens, the standard for letting apps and third parties connect safely. '
        'For production, the API should move off http.server and Basic Auth to a '
        'framework with token-based auth behind HTTPS.', body))

    doc.build(story)
    print('Saved', OUT)


if __name__ == '__main__':
    build()