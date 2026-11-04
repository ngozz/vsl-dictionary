# English translation pipeline — dictionary

The pipeline is: `build_work.dart` → translate the work files → `validate.dart`
→ `merge.dart`. The shipped result is `data/i18n/en/vsl_data_en.json`; the app
reads it as a sidecar and falls back to Vietnamese when a key is missing.

Generated work files and validation reports are written to `data/i18n/work/` and
`data/i18n/validation-*.txt` and are git-ignored, because they can be recreated
from the source data. Only the tooling in this folder and the shipped sidecar are
committed.

---

# Translation instructions — dictionary

The work files described here cover `data/vsl_data.json` (**3,325 entries**)
and are generated into `data/i18n/work/` (git-ignored).

There are **23 files**: `dictionary/part-01.json` … `dictionary/part-23.json`
(150 entries each). Each file is already filled with Vietnamese; the job is to
replace the Vietnamese with American English.

The finished sidecar (`data/i18n/en/vsl_data_en.json`) is generated later from
these files — do not edit that by hand.

---

## How to run one file

1. Open a fresh chat with the AI.
2. Paste the prompt below.
3. Attach or paste **one** `part-XX.json` file.
4. Copy the AI's JSON answer and save it over the same file (UTF-8, no BOM).
5. Continue with the next part.

Feed order does not matter. If an answer is cut off, reply
`continue from the last complete entry` and append the rest.

---

## Prompt (paste once per chat)

```text
You are translating a Vietnamese Sign Language dictionary into American English.

The attached JSON file is a dictionary work file. Its keys are entry ids; each
value has two fields, "word" and "description". Both are still in Vietnamese.
Replace them with English.

RULES
1. Output the same JSON object: same keys, same key order, same number of
   entries. Do not add, remove, rename or reorder anything.
2. Keep keys exactly as written, including ids like "W03243#2". Never translate
   keys, ids, or the "_note" field.
3. "word": the shortest natural English gloss (1–3 words). Choose the sense that
   the description explains.
4. "description": 1–2 sentences of American English that ADD context — explain
   the meaning or the sign and the situation it is used in. Do not just list
   synonyms. Do not write a grammar lesson.
5. This is not a replacement for the Vietnamese definition. The app shows the
   Vietnamese meaning from the original data and your English text as a
   companion gloss, so your text must stand on its own in English.
6. Use the same English gloss every time the same Vietnamese word has the same
   meaning.
7. Keep names of people and places in Vietnamese (for example "Hồ Chí Minh").
8. Leave an empty string empty.
9. Output valid JSON only. No markdown fences, no explanations, no comments.
```

## Style notes

- Use **American English** (`color`, `center`, `practice` as a verb, etc.).
- Learner-friendly register; no academic jargon.
- Describe the sign when the source describes the sign (hand shape, movement,
  repeated action), not just the concept.
- If a word has no exact English equivalent, translate the meaning and keep the
  Vietnamese term in parentheses once.
- Do not translate `_word`, `tl`, `type` — they are not in these files, and they
  must stay untouched in the source.

## Check before moving on

- [ ] Same number of entries as the input.
- [ ] No Vietnamese text left (except proper names / bracketed terms).
- [ ] `word` is short; `description` is 1–2 sentences.
- [ ] Numbers and punctuation unchanged.

## Files

```
dictionary/part-01.json … part-23.json
```

Last part has fewer entries (25). That is expected.
