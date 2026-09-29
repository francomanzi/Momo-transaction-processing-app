"""Parse modified_sms_v2.xml into a list of JSON transaction objects.

Each SMS record keeps its key fields from the XML plus a simple
amount extracted from the body text.
"""

import json
import os
import re
import xml.etree.ElementTree as ET

XML_PATH = os.path.join('data', 'modified_sms_v2.xml')
JSON_PATH = os.path.join('data', 'modified_sms_v2.json')

# First amount that looks like "<number> RWF" in the body (e.g. "1,000 RWF")
AMOUNT_RE = re.compile(r'(\d[\d,]*)\s*RWF')

# Key fields we want to keep from every <sms> element
KEY_FIELDS = (
    'address',
    'date',
    'readable_date',
    'type',
    'status',
    'body',
    'contact_name',
    'service_center',
)


def extract_amount(body):
    """Return the first RWF amount in body as a float, or None."""
    match = AMOUNT_RE.search(body or '')
    if not match:
        return None
    return float(match.group(1).replace(',', ''))


def parse_xml(xml_path=XML_PATH):
    """Parse the SMS XML file into a list of dicts."""
    tree = ET.parse(xml_path)
    root = tree.getroot()
    transactions = []
    for index, element in enumerate(root.findall('sms'), start=1):
        record = {'id': index}
        for field in KEY_FIELDS:
            record[field] = element.get(field)
        record['amount'] = extract_amount(record['body'])
        transactions.append(record)
    return transactions


def save_json(transactions, json_path=JSON_PATH):
    """Write the transaction list to a JSON file."""
    with open(json_path, 'w', encoding='utf-8') as handle:
        json.dump(transactions, handle, indent=2, ensure_ascii=False)


if __name__ == '__main__':
    parsed = parse_xml()
    save_json(parsed)
    print(f'Parsed {len(parsed)} SMS records -> {JSON_PATH}')