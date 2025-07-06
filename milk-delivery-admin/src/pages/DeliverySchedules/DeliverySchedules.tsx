import React from 'react';
import { Typography } from '@mui/material';

const DeliverySchedules: React.FC = () => {
  return (
    <div>
      <Typography variant="h4" gutterBottom>
        Delivery Schedules
      </Typography>
      <Typography variant="body1">
        Manage delivery schedules here.
      </Typography>
    </div>
  );
};

export default DeliverySchedules;