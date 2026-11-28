"""Regressões de aceite, sem credenciais ou chamadas de rede."""
import unittest
from decimal import Decimal
from unittest.mock import patch

import aceite


class AceiteTest(unittest.TestCase):
    def test_custo_minimo_e_arredondamento(self):
        price = Decimal(5)
        unit = price / 2**20
        self.assertEqual(aceite.estimated_cost(1, price), 10 * unit)
        self.assertEqual(aceite.estimated_cost(68 * aceite.MIB, price), 68 * unit)
        self.assertEqual(aceite.estimated_cost(68 * aceite.MIB + 1, price), 69 * unit)

    def test_ausencia_exige_erro_especifico(self):
        for code in ("403", "ExpiredToken", "ThrottlingException"):
            error = aceite.AwsError(f"An error occurred ({code}) when calling HeadBucket")
            with self.subTest(code=code), patch.object(aceite, "aws", side_effect=error):
                with self.assertRaises(aceite.AwsError):
                    aceite.absent("404", "s3api", "head-bucket")
        missing = aceite.AwsError("An error occurred (404) when calling HeadBucket")
        with patch.object(aceite, "aws", side_effect=missing):
            aceite.absent("404", "s3api", "head-bucket")

    def test_consulta_larga_exige_motivo_do_teto(self):
        with patch.object(aceite, "config", {"database_name":"crime", "table_name":"trusted"}, create=True):
            for reason in ("Access denied", "Table not found"):
                run = {"Status":{"State":"FAILED", "StateChangeReason":reason}}
                with patch.object(aceite, "query", return_value=run), self.assertRaises(ValueError):
                    aceite.broad_query()
            run = {"Status":{"State":"CANCELLED", "StateChangeReason":"Query exceeded bytes scanned limit"}}
            with patch.object(aceite, "query", return_value=run):
                aceite.broad_query()

    def test_backend_com_lock_ou_outra_chave(self):
        config = {"state_bucket":"bucket-av1","conta":"123456789012","lock_table":"lock"}
        with patch.object(aceite, "config", config, create=True):
            with patch.object(aceite, "aws", return_value={"Contents":[{"Key":"outro/estado"}]}):
                with self.assertRaisesRegex(ValueError, "imprevista"):
                    aceite.backend_free()
            with patch.object(aceite, "aws", side_effect=[{}, {"Items":[{"LockID":{"S":"ativo"}}]}]):
                with self.assertRaisesRegex(ValueError, "lock"):
                    aceite.backend_free()


if __name__ == "__main__":
    unittest.main()
