"""Compare linear search vs dictionary lookup for finding transactions by id.

Requirement: measure/compare efficiency for at least 20 records.
We search for the first 20 ids and repeat over several runs so the
timing difference is clearly measurable.
"""

import os
import random
import time

from dsa.parse_xml import parse_xml


def linear_search(transactions, target_id):
    """Scan the list until the id matches. Returns the record or None."""
    for record in transactions:
        if record['id'] == target_id:
            return record
    return None


def dict_lookup(by_id, target_id):
    """Fetch directly from a dictionary keyed by id. Returns the record or None."""
    return by_id.get(target_id)


def measure(transactions, by_id, target_ids, runs=5):
    """Time both methods over the target ids, repeated `runs` times."""
    linear_total = 0.0
    dict_total = 0.0

    for _ in range(runs):
        start = time.perf_counter()
        for target_id in target_ids:
            linear_search(transactions, target_id)
        linear_total += time.perf_counter() - start

        start = time.perf_counter()
        for target_id in target_ids:
            dict_lookup(by_id, target_id)
        dict_total += time.perf_counter() - start

    return linear_total / runs, dict_total / runs


def main():
    transactions = parse_xml()
    by_id = {record['id']: record for record in transactions}

    n_ids = 20
    target_ids = random.sample(list(by_id.keys()), n_ids)
    linear_avg, dict_avg = measure(transactions, by_id, target_ids)

    lines = [
        'DSA comparison: linear search vs dictionary lookup',
        f'records in dataset : {len(transactions)}',
        f'ids searched        : {n_ids} (random ids: {sorted(target_ids)})',
        f'linear search total (avg over runs) : {linear_avg:.6f} s',
        f'dictionary lookup total (avg)       : {dict_avg:.6f} s',
        f'dictionary is {linear_avg / dict_avg:.1f}x faster',
        '',
        'Why is dictionary lookup faster?',
        'A dictionary stores values by a hash of the key, so a lookup goes',
        'straight to the slot in O(1) time. Linear search must compare every',
        'element from the start, so in the worst case it scans all N records',
        'in O(N) time.',
        '',
        'Could another data structure improve search efficiency?',
        'A sorted list plus binary search finds an id in O(log N) steps,',
        'much faster than a linear scan, and it keeps records sorted.',
        'For reads that never change, this is a good alternative.',
    ]
    output = '\n'.join(lines)
    print(output)

    os.makedirs('data/logs', exist_ok=True)
    with open(os.path.join('data', 'logs', 'dsa_results.txt'), 'w') as handle:
        handle.write(output)
    print(f'\n(written to data/logs/dsa_results.txt)')


if __name__ == '__main__':
    main()