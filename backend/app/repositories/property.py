from __future__ import annotations

import random
from dataclasses import dataclass
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


@dataclass(frozen=True)
class PropertyRecord:
    product_id: str
    product_name: str
    property_type: str
    bedrooms: int
    bathrooms: int
    price: float
    is_pet_friendly: int
    region_id: str
    region_name: str


class PropertyRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_all(self) -> list[dict]:
        result = await self.session.execute(
            text("""
                SELECT p.product_id, p.product_name, p.property_type,
                       p.bedrooms, p.bathrooms, p.price, p.is_pet_friendly,
                       r.region_name
                FROM property_listing p
                JOIN region r ON r.region_id = p.region_id
                ORDER BY p.product_id ASC
            """)
        )
        return [dict(row) for row in result.mappings().all()]

    async def next_product_id(self) -> str:
        result = await self.session.execute(
            text("""
                SELECT COALESCE(MAX(CAST(SUBSTRING(product_id, 2) AS UNSIGNED)), 0) + 1
                FROM property_listing
                WHERE product_id REGEXP '^P[0-9]+$'
            """)
        )
        number = int(result.scalar_one())
        return f"P{number:03d}"

    async def create_random(self) -> PropertyRecord:
        regions = (await self.session.execute(text(
            "SELECT region_id, region_name FROM region ORDER BY region_id"
        ))).mappings().all()
        if not regions:
            raise RuntimeError("No rental regions configured")

        region = random.choice(regions)
        property_type = random.choice(["Apartment", "House", "Townhouse", "Studio"])
        bedrooms = 0 if property_type == "Studio" else random.randint(1, 5)
        bathrooms = random.randint(1, min(3, max(1, bedrooms)))
        price = round(random.uniform(450, 1800), 2)
        pet_friendly = random.randint(0, 1)
        product_id = await self.next_product_id()
        record = PropertyRecord(
            product_id=product_id,
            product_name=f"{random.randint(1, 999)} {random.choice(['George', 'Victoria', 'Chapel', 'Church'])} St, {region['region_name']}",
            property_type=property_type,
            bedrooms=bedrooms,
            bathrooms=bathrooms,
            price=price,
            is_pet_friendly=pet_friendly,
            region_id=region["region_id"],
            region_name=region["region_name"],
        )
        await self.session.execute(text("""
            INSERT INTO property_listing
              (product_id, product_name, property_type, bedrooms, bathrooms,
               price, is_pet_friendly, region_id, availability_status)
            VALUES (:product_id, :product_name, :property_type, :bedrooms,
                    :bathrooms, :price, :is_pet_friendly, :region_id, 'available')
        """), record.__dict__)
        await self.session.execute(text("""
            INSERT INTO outbox_event
              (aggregate_type, aggregate_id, event_type, payload)
            VALUES ('property_listing', :product_id, 'PROPERTY_CREATED',
                    CAST(:payload AS JSON))
        """), {
            "product_id": record.product_id,
            "payload": _json_payload(record),
        })
        await self.session.commit()
        return record


def _json_payload(record: PropertyRecord) -> str:
    import json
    return json.dumps({
        "product_id": record.product_id,
        "product_name": record.product_name,
        "property_type": record.property_type,
        "bedrooms": record.bedrooms,
        "bathrooms": record.bathrooms,
        "price": record.price,
        "is_pet_friendly": record.is_pet_friendly,
        "region_id": record.region_id,
        "region_name": record.region_name,
    }, ensure_ascii=False)
