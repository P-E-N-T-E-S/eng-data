import sys
import unittest
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dados"))
import pipeline_local


class LocalPipelineTest(unittest.TestCase):
    def test_refined_uses_state_scope_and_preserves_missing_month(self):
        frame = pd.DataFrame([
            {"uf": "PE", "evento": "Homicídio doloso", "abrangencia": "Estadual", "total_vitima": 2, "mes": 1},
            {"uf": "PE", "evento": "Homicídio doloso", "abrangencia": "Estadual", "total_vitima": 3, "mes": 2},
            {"uf": "PE", "evento": "Homicídio doloso", "abrangencia": "Estadual", "total_vitima": None, "mes": 3},
            {"uf": "PE", "evento": "Homicídio doloso", "abrangencia": "Municipal", "total_vitima": 100, "mes": 1},
            {"uf": "PE", "evento": "Feminicídio", "abrangencia": "Estadual", "total_vitima": 50, "mes": 1},
        ])
        for index in range(26):
            frame.loc[len(frame)] = [f"U{index:02}", "Homicídio doloso", "Estadual", 0, 1]

        result = pipeline_local.refined(frame, 2024)
        pe = result[result["uf"] == "PE"].iloc[0]
        self.assertEqual(pe["vitimas"], 5)
        self.assertEqual(pe["meses_informados"], 2)

    def test_refined_is_deterministic(self):
        frame = pd.DataFrame([
            {"uf": f"U{index:02}", "evento": "Homicídio doloso", "abrangencia": "Estadual",
             "total_vitima": index, "mes": 1}
            for index in range(27)
        ])
        first = pipeline_local.refined(frame, 2024)
        second = pipeline_local.refined(frame.sample(frac=1, random_state=7), 2024)
        pd.testing.assert_frame_equal(first.reset_index(drop=True), second.reset_index(drop=True))


if __name__ == "__main__":
    unittest.main()
